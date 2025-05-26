require 'timeout'

# Функция для чтения файла и парсинга строк
def read_file(filename)
  return [] unless File.exist?(filename)
  File.readlines(filename, chomp: true).map { |line| line.split('|') }
rescue Errno::ENOENT
  puts "Ошибка: файл #{filename} не найден!"
  []
end

# Функция для получения случайного комментария с цветной подсветкой
def get_comment(comments, type)
  comment = comments.select { |c| c[0] == type }.sample[1]
  color = type == 'correct' ? "\e[32m" : "\e[31m" # Зеленый для correct, красный для error
  "#{color}#{comment}\e[0m" # Сброс цвета после комментария
end

# Функция для ответа бота с учетом сложности
def bot_answer(correct_answer, difficulty)
  probability = case difficulty
                when 'легкая' then 0.5
                when 'средняя' then 0.7
                when 'тяжелая' then 0.9
                else 0.7 # Средняя по умолчанию
                end
  rand < probability ? correct_answer : ('A'..'Z').to_a.sample(5).join.downcase
end

# Загрузка данных
questions = read_file('questions.txt')
bonus_questions = read_file('bonus_questions.txt')
comments = read_file('comments.txt')

# Проверка наличия данных
if questions.empty? || bonus_questions.empty? || comments.empty?
  puts "Не удалось загрузить данные. Проверьте файлы questions.txt, bonus_questions.txt и comments.txt."
  exit
end

# Инициализация массивов для отслеживания использованных вопросов
used_questions = []
used_bonus_questions = []

# Выбор сложности бота
puts "Выберите сложность бота (легкая, средняя, тяжелая):"
difficulty = gets.chomp.downcase
until %w[легкая средняя тяжелая].include?(difficulty)
  puts "Неверный выбор. Введите легкая, средняя или тяжелая:"
  difficulty = gets.chomp.downcase
end
puts "Вы выбрали сложность: #{difficulty}"

# Установка времени ответа в зависимости от сложности
answer_time = { 'легкая' => 20, 'средняя' => 15, 'тяжелая' => 10 }
puts "Время на ответ: #{answer_time[difficulty]} сек"

# Инициализация игры
total_score = 0      # Общий счет игрока
bot_score = 0        # Счет бота
chain_count = 0      # Количество правильных ответов в текущей цепочке
chain_score = 0      # Очки текущей цепочки
win_score = 500      # Цель игры

puts "\nДобро пожаловать в 'Слабое звено'! Набери #{win_score} очков раньше бота, чтобы выиграть!"

loop do
  # Проверка условия победы
  if total_score >= win_score || bot_score >= win_score
    puts "\nИтоговый счет: Вы - #{total_score}, Бот - #{bot_score}"
    puts total_score >= win_score && total_score > bot_score ? "Вы выиграли!" : "Бот выиграл!"
    break
  end

  # Решение о сохранении банка (без таймера)
  if chain_score > 0
    loop do
      puts "\nЗабрать очки текущей цепочки (#{chain_score})? (да/нет)"
      take_score = gets.chomp.downcase
      if take_score == 'да'
        total_score += chain_score
        puts "Вы забрали #{chain_score} очков!"
        puts "\e[34mОбщий счет: Вы - #{total_score} / Бот - #{bot_score}\e[0m"
        chain_count = 0
        chain_score = 0
        break
      elsif take_score == 'нет'
        puts "Цепочка сохранена, продолжаем!"
        break
      else
        puts "Неверный ввод. Введите да или нет."
      end
    end
  end

  # Выбор типа вопроса: обычный или бонусный (10% шанс на бонусный)
  is_bonus = rand < 0.1
  question_set = is_bonus ? bonus_questions - used_bonus_questions : questions - used_questions

  # Проверка на наличие доступных вопросов
  if question_set.empty?
    puts "\nВопросы #{is_bonus ? 'бонусные' : 'обычные'} закончились! Игра завершена."
    puts "Итоговый счет: Вы - #{total_score}, Бот - #{bot_score}"
    puts total_score > bot_score ? "Вы выиграли!" : "Бот выиграл!"
    break
  end

  question = question_set.sample
  # Добавление вопроса в использованные
  if is_bonus
    used_bonus_questions << question
  else
    used_questions << question
  end

  puts "\n#{is_bonus ? "\e[33mБОНУСНЫЙ ВОПРОС (про Ruby, x2 очки): #{question[0]}\e[0m" : "\e[33mВопрос: #{question[0]}\e[0m"}"

  # Ответ игрока с таймером (зависит от сложности)
  player_answer = nil
  begin
    Timeout.timeout(answer_time[difficulty]) do
      print "Ваш ответ: "
      player_answer = gets.chomp.downcase
    end
  rescue Timeout::Error
    chain_count = 0
    chain_score = 0
    comment = get_comment(comments, 'error')
    puts "\n\e[31mВремя вышло!\e[0m #{comment} Цепочка сброшена."
  end

  # Проверка ответа игрока
  if player_answer
    if player_answer == question[1].downcase
      chain_count += 1
      points = 10 * (2 ** (chain_count - 1)) # 10, 20, 40, 80, ...
      points *= 2 if is_bonus # Бонусные вопросы дают x2 очки
      chain_score += points
      comment = get_comment(comments, 'correct')
      puts "\e[32mПравильно!\e[0m #{comment} (Очки за цепочку: #{chain_score})"
      puts "Очки в банке: #{total_score}"
    else
      chain_count = 0
      chain_score = 0
      comment = get_comment(comments, 'error')
      puts "\e[31mНеправильно.\e[0m #{comment} Ответ: #{question[1]} Цепочка сброшена."
    end
  end

  # Ответ бота
  bot_answer = bot_answer(question[1].downcase, difficulty)
  puts "\e[90mБот ответил: #{bot_answer}\e[0m"
  if bot_answer == question[1].downcase
    bot_points = points || 0 # Бот получает те же очки, что и игрок за этот вопрос
    bot_score += bot_points
    puts "\e[90mБот ответил правильно! Его очки: #{bot_score}\e[0m"
  else
    puts "\e[90mБот ответил неправильно.\e[0m"
  end
end