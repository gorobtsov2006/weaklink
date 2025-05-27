#!/usr/bin/env ruby
require 'timeout'

# Читает файл и возвращает массив строк, разделенных по символу |
def read_file(filename)
  return [] unless File.exist?(filename)
  File.readlines(filename, encoding: 'UTF-8').map { |line| line.chomp.split('|') }
rescue Errno::ENOENT
  puts "Ошибка: Файл #{filename} не найден."
  []
end

# Возвращает случайный комментарий с цветной подсветкой
def get_comment(comments, type)
  comment = comments.select { |c| c[0] == type }.sample[1]
  color = type == 'correct' ? "\e[32m" : "\e[31m" # Зеленый для correct, красный для error
  "#{color}#{comment}\e[0m"
end

# Определяет ответ бота и следующее состояние на основе текущего состояния и переходов
def bot_answer(correct_answer, bot_state, bot_transitions, p)
  if bot_state == 3
    # В состоянии 3 бот всегда отвечает неправильно и остаётся в 3
    new_state = 3
    answer = ('A'..'Z').to_a.sample(5).join.downcase
  else
    # В состояниях 0, 1, 2: выбор перехода по вероятности p
    transition = bot_transitions[bot_state]
    should_be_correct = rand < p
    new_state = should_be_correct ? transition.keys.first : transition.keys.last
    answer = should_be_correct ? correct_answer : ('A'..'Z').to_a.sample(5).join.downcase
  end
  # puts "\e[90m[DEBUG] Бот: состояние=#{bot_state}, p=#{p.round(2)}, правильный?=#{should_be_correct}, новое состояние=#{new_state}\e[0m"
  [answer, new_state]
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

# Фиксированная вероятность p для всей игры
p = rand
# puts "\e[90m[DEBUG] Фиксированная вероятность p = #{p.round(2)}\e[0m"

# Определение переходов бота (вероятностный автомат)
bot_transitions = {
  0 => { 1 => p, 3 => 1 - p },
  1 => { 2 => p, 3 => 1 - p },
  2 => { 3 => p, 2 => 1 - p }
}

# Установка времени ответа (фиксированное)
answer_time = 15
puts "Время на ответ: #{answer_time} сек"

# Инициализация игры
total_score = 0      # Общий счет игрока
bot_score = 0        # Счет бота
chain_count = 0      # Количество правильных ответов в текущей цепочке
chain_score = 0      # Очки текущей цепочки
win_score = 500      # Цель игры
bot_state = 0        # Начальное состояние бота

puts "\nДобро пожаловать в 'Слабое звено'! Набери #{win_score} очков раньше бота, чтобы выиграть!"

loop do
  # Проверка условия победы
  if total_score >= win_score || bot_score >= win_score
    puts "\n\e[34mИтоговый счет: Вы - #{total_score} / Бот - #{bot_score}\e[0m"
    puts "\e[32m#{total_score >= win_score && total_score > bot_score ? 'Вы выиграли!' : 'Бот выиграл!'}\e[0m"
    break
  end

  # Решение о сохранении банка
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

  # Выбор типа вопроса: обычный или бонусный (10% шанс)
  is_bonus = rand < 0.1
  question_set = is_bonus ? bonus_questions - used_bonus_questions : questions - used_questions

  # Проверка на наличие вопросов
  if question_set.empty?
    puts "\nВопросы #{is_bonus ? 'бонусные' : 'обычные'} закончились! Игра завершена."
    puts "\e[34mИтоговый счет: Вы - #{total_score} / Бот - #{bot_score}\e[0m"
    puts "\e[32m#{total_score > bot_score ? 'Вы выиграли!' : 'Бот выиграл!'}\e[0m"
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

  # Ответ игрока с таймером
  player_answer = nil
  begin
    Timeout.timeout(answer_time) do
      print "Ваш ответ: "
      player_answer = gets.chomp.downcase
    end
  rescue Timeout::Error
    chain_count = 0
    chain_score = 0
    comment = get_comment(comments, 'error')
    puts "\n\e[31mВремя вышло!\e[0m #{comment}"
    puts "(Цепочка сброшена.)"
  end

  # Проверка команды stop
  if player_answer == 'stop'
    puts "\nИгра завершена по вашей команде."
    puts "\e[34mИтоговый счет: Вы - #{total_score} / Бот - #{bot_score}\e[0m"
    puts "\e[32m#{total_score > bot_score ? 'Вы выиграли!' : 'Бот выиграл!'}\e[0m"
    break
  end

  # Вычисление очков за вопрос
  points = chain_count.zero? ? 10 : 10 * (2 ** (chain_count - 1)) # 10, 20, 40, 80, ...
  points *= 2 if is_bonus # Бонусные вопросы дают x2 очки

  # Проверка ответа игрока
  if player_answer
    if player_answer == question[1].strip.downcase
      chain_count += 1
      chain_score += points
      comment = get_comment(comments, 'correct')
      puts "\e[32mПравильно!\e[0m #{comment} (Очки за цепочку: #{chain_score})"
      puts "Очки в банке: #{total_score}"
    else
      chain_count = 0
      chain_score = 0
      comment = get_comment(comments, 'error')
      puts "\e[31mНеправильно.\e[0m #{comment}"
      puts "\e[36mОтвет: #{question[1]}\e[0m"
      puts "(Цепочка сброшена.)"
    end
  end

  # Ответ бота
  bot_answer, new_bot_state = bot_answer(question[1].strip.downcase, bot_state, bot_transitions, p)
  puts "\e[90mБот ответил: #{bot_answer}\e[0m"
  if bot_answer == question[1].strip.downcase
    bot_score += points
    puts "\e[90mБот ответил правильно! Его очки: #{bot_score}\e[0m\n"
  else
    puts "\e[90mБот ответил неправильно.\e[0m\n"
  end

  # Обновление состояния бота
  bot_state = new_bot_state
end