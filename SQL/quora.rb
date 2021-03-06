require 'sqlite3'
require 'singleton'

class QuoraDBConnection < SQLite3::Database
  include Singleton

  def initialize
    super('quora.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class Users
  attr_accessor :fname, :lname

  def self.all
    data = QuoraDBConnection.instance.execute("SELECT * FROM users")
    data.map { |datum| Users.new(datum) }
  end

  def authored_questions
    Question.find_by_author_id(self.id)
  end

  def authored_replies
    Replies.find_by_user_id(self.id)
  end

  def liked_questions
    QuestionLikes.liked_questions_for_user_id(self.id)
  end

  def average_karma
    questions_by_me = authored_questions
    sum_likes = 0
    questions_by_me.each do |question|
      sum_likes += question.num_likes
    end
    sum_likes / questions_by_me.length
  end

  def self.find_by_name(fname, lname)
    user = QuoraDBConnection.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL
    return nil unless user.length > 0

    Users.new(user.first)
  end

  def self.find_by_lname(lname)
    user = QuoraDBConnection.instance.execute(<<-SQL, lname)
      SELECT
        *
      FROM
        users
      WHERE
        lname = ?
    SQL
    return nil unless user.length > 0

    Users.new(user.first)
  end

  def self.find_by_id(id)
    user = QuoraDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL
    return nil unless user.length > 0

    Users.new(user.first)
  end

  def self.find_by_fname(fname)
    user = QuoraDBConnection.instance.execute(<<-SQL, fname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ?
    SQL
    return nil unless user.length > 0

    Users.new(user.first)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(self.id)
  end

  attr_reader :id

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def create
    raise "#{self} already in database" if @id
    QuoraDBConnection.instance.execute(<<-SQL, @fname, @lname)
      INSERT INTO
        users (fname, lname)
      VALUES
        (?, ?)
    SQL
    @id = QuoraDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuoraDBConnection.instance.execute(<<-SQL, @fname, @lname, @id)
      UPDATE
        users
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
    SQL
  end
end

class Question
  attr_accessor :title, :body
  attr_reader :id, :author_id

  def self.all
    data = QuoraDBConnection.instance.execute("SELECT * FROM questions")
    data.map { |datum| Question.new(datum) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.find_by_title(title)
    ques = QuoraDBConnection.instance.execute(<<-SQL, title)
      SELECT
        *
      FROM
        questions
      WHERE
        title = ?
    SQL
    return nil unless ques.length > 0 # person is stored in an array!

    Question.new(ques.first)
  end

  def likers
    QuestionLikes.likers_for_question_id(self.id)
  end

  def num_likes
    QuestionLikes.num_likes_for_question_id(self.id)
  end

  def self.most_liked(n)
    QuestionLikes.most_liked_questions(n)
  end

  def self.find_by_author_id(author_id)
    ques = QuoraDBConnection.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL
    return nil unless ques.length > 0 # person is stored in an array!

    ques.map {|obj| Question.new(obj)}
  end

  def self.find_by_id(id)
    ques = QuoraDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
    SQL
    return nil unless ques.length > 0 # person is stored in an array!

    Question.new(ques.first)
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def author
    Users.find_by_id(self.author_id)
  end

  def replies
    Replies.find_by_question_id(self.id)
  end

  def followers
    QuestionFollow.followers_for_question_id(self.id)
  end

  def create
    raise "#{self} already in database" if @id
    QuoraDBConnection.instance.execute(<<-SQL, @title, @body, @author_id)
      INSERT INTO
        questions (title, body, author_id)
      VALUES
        (?, ?, ?)
    SQL
    @id = QuoraDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuoraDBConnection.instance.execute(<<-SQL, @title, @body, @author_id, @id)
      UPDATE
        questions
      SET
        title = ?, body = ?, author_id = ?
      WHERE
        id = ?
    SQL
  end

end

class QuestionFollow
  attr_reader :id, :user_id, :question_id

  def self.all
    data = QuoraDBConnection.instance.execute("SELECT * FROM question_follows")
    data.map { |datum| QuestionFollow.new(datum) }
  end

  def self.find_by_user_id(user_id)
    ques = QuoraDBConnection.instance.execute(<<-SQL, @user_id)
      SELECT
        *
      FROM
        question_follows
      WHERE
        user_id = ?
    SQL
    return nil unless ques.length > 0 # person is stored in an array!

    QuestionFollow.new(ques.first)
  end

  def self.most_followed_questions(n)
    QuoraDBConnection.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      JOIN
        question_follows ON questions.id = question_follows.question_id
      GROUP BY
       question_follows.question_id
      ORDER BY
      COUNT(question_follows.question_id)
       DESC
      LIMIT(?)
    SQL
  end

  def self.followers_for_question_id(question_id)
    QuoraDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        users.*
      FROM
        users
      JOIN
        question_follows ON users.id = question_follows.user_id
      WHERE
        question_follows.question_id = ?
    SQL
  end

  def self.followed_questions_for_user_id(user_id)
    QuoraDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        question_follows
      JOIN
        questions ON question_follows.question_id = questions.id
      WHERE
        question_follows.user_id = ?
    SQL
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def create
    raise "#{self} already in database" if @id
    QuoraDBConnection.instance.execute(<<-SQL, @user_id, @question_id)
      INSERT INTO
        question_follows (user_id, question_id)
      VALUES
        (?, ?)
    SQL
    @id = QuoraDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuoraDBConnection.instance.execute(<<-SQL, @user_id, @question_id, @id)
      UPDATE
        question_follows
      SET
        user_id = ?, question_id = ?
      WHERE
        id = ?
    SQL
  end
end

class Replies
  attr_reader :id, :question_id, :parent_id, :reply_author
  attr_accessor :body

  def self.all
    data = QuoraDBConnection.instance.execute("SELECT * FROM replies")
    data.map { |datum| Replies.new(datum) }
  end

  def self.find_by_id(id)
    reply = QuoraDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        replies
      WHERE
        id = ?
    SQL
    return nil unless reply.length > 0 # person is stored in an array!

    Replies.new(reply.first)
  end

  def self.find_by_question_id(question_id)
    reply = QuoraDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL
    return nil unless reply.length > 0 # person is stored in an array!

    Replies.new(reply.first)
  end

  def self.find_by_user_id(user_id)
    reply = QuoraDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL
    return nil unless reply.length > 0 # person is stored in an array!

    Replies.new(reply.first)
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @parent_id = options['parent_id']
    @reply_author = options['reply_author']
    @body = options['body']
  end

  def author
    Users.find_by_id(self.reply_author)
  end

  def child_replies
      parent = self.id
      QuoraDBConnection.instance.execute(<<-SQL, parent)
        SELECT
          *
        FROM
          replies
        WHERE
          parent_id = ?
      SQL
  end

  def question
    Question.find_by_id(question_id)
  end

  def parent_reply
    return nil if @parent_id.nil?
    Replies.find_by_id(self.parent_id)
  end

  def create
    raise "#{self} already in database" if @id
    QuoraDBConnection.instance.execute(<<-SQL, @question_id, @parent_id, @reply_author, @body)
      INSERT INTO
        replies (question_id, parent_id, reply_author, body)
      VALUES
        (?, ?, ?, ?)
    SQL
    @id = QuoraDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuoraDBConnection.instance.execute(<<-SQL, @question_id, @parent_id, @reply_author, @body, @id)
      INSERT INTO
        replies (question_id, parent_id, reply_author, body)
      VALUES
        (?, ?, ?, ?)
      WHERE
        id = ?
    SQL
  end
end

class QuestionLikes
  attr_reader :id, :user_id, :question_id

  def self.all
    data = QuoraDBConnection.instance.execute("SELECT * FROM question_likes")
    data.map { |datum| QuestionLikes.new(datum) }
  end

  def self.find_by_user_id(user_id)
    ques = QuoraDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        question_likes
      WHERE
        user_id = ?
    SQL
    return nil unless ques.length > 0 # person is stored in an array!

    QuestionLikes.new(ques.first)
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def create
    raise "#{self} already in database" if @id
    QuoraDBConnection.instance.execute(<<-SQL, @user_id, @question_id, @id)
      INSERT INTO
        question_likes (user_id, question_id,)
      VALUES
        (?, ?)
    SQL
    @id = QuoraDBConnection.instance.last_insert_row_id
  end

  def self.most_liked_questions(n)
    QuoraDBConnection.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id
      GROUP BY
       question_likes.question_id
      ORDER BY
      COUNT(question_likes.question_id)
       DESC
      LIMIT(?)
    SQL
  end

  def self.likers_for_question_id(question_id)
    QuoraDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        DISTINCT users.*
      FROM
        users
      JOIN
        question_likes ON users.id = question_likes.user_id
      WHERE
        question_likes.question_id = ?
    SQL
  end

  def self.likes_questions_for_user_id(user_id)
    queries = QuoraDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        question_likes.user_id = ?
    SQL

    queries.map{ |datum| Question.new(datum) }
  end

  def self.num_likes_for_question_id(question_id)
    users_arr = self.likers_for_question_id(question_id)
    users_arr.length
  end

  def update
    raise "#{self} not in database" unless @id
    QuoraDBConnection.instance.execute(<<-SQL, @user_id, @question_id, @id)
      UPDATE
        question_likes
      SET
        user_id = ?, question_id = ?
      WHERE
        id = ?
    SQL
  end
end
