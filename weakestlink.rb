require 'timeout'

def read_file(filename)
  return [] unless File.exist?(filename)
  File.readlines(filename, chomp: true).map { |line| line.split('|') }
rescue Errno::ENOENT
  puts "Ошибка: файл #{filename} не найден!"
  []
end

questions = read_file('questions.txt')
bonus_questions = read_file('bonus_questions.txt')
comments = read_file('comments.txt')
hints = read_file('hints.txt').to_h

if questions.empty?  bonus_questions.empty?  comments.empty?
  puts "Не удалось загрузить данные. Проверьте файлы questions.txt, bonus_questions.txt и comments.txt."
  exit
end

score = 0
chain = [10, 20, 40, 80, 160, 320, 640, 1280]
chain_index = 0
bot_score = 0

def get_comment(comments, type)
  comments.select { |c| c[0] == type }.sample[1]
end

def bot_answer(correct_answer)
  rand < 0.7 ? correct_answer : (('A'..'Z').to_a.sample(5).join.downcase)
end

puts "Добро пожаловать в 'Слабое звено'! Отвечай на вопросы, соревнуйся с ботом и забирай очки, пока не поздно!"

loop do
  is_bonus = rand < 0.1
  question_set = is_bonus ? bonus_questions : questions
  question = question_set.sample
  puts "\n#{is_bonus ? 'БОНУСНЫЙ ВОПРОС (про Ruby):' : 'Вопрос:'} #{question[0]}"

  unless is_bonus
    puts "Нужна подсказка? (y/n)"
    if gets.chomp.downcase == 'y'
      hint = hints[question[0]]
      puts "Подсказка: #{hint || 'Нет подсказки для этого вопроса'}"
    end
  end

  player_answer = nil
  begin
    Timeout.timeout(10) do
      print "Ваш ответ: "
      player_answer = gets.chomp.downcase
    end
  rescue Timeout::Error
    chain_index = 0
    comment = get_comment(comments, 'error')
    puts "Время вышло! #{comment}"
  end

  bot_ans = bot_answer(question[1].downcase)
  puts "Бот ответил: #{bot_ans}"

  if player_answer
    if player_answer == question[1].downcase
      points = is_bonus ? chain[chain_index] * 2 : chain[chain_index]
      score += points
      chain_index = [chain_index + 1, chain.length - 1].min
      comment = get_comment(comments, 'correct')
      puts "Правильно! #{comment} Очки: #{score}"
    else
      chain_index = 0
      comment = get_comment(comments, 'error')
      puts "Неправильно. #{comment} Ответ: #{question[1]}"
    end
  end

  if bot_ans == question[1].downcase
    bot_score += chain[chain_index]
    puts "Бот ответил правильно! Его очки: #{bot_score}"
  else
    puts "Бот ответил неправильно."
  end

  puts "\nЗабрать очки? (y/n)"
  break if gets.chomp.downcase == 'y'
end

puts "\nИтоговый счет: Вы - #{score}, Бот - #{bot_score}"
puts score > bot_score ? "Вы выиграли!" : "Бот выиграл!"