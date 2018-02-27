CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname VARCHAR(55) NOT NULL,
  lname VARCHAR(55) NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  author_id INTEGER NOT NULL,

  FOREIGN KEY(author_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  parent_id INTEGER,
  reply_author INTEGER NOT NULL,
  body TEXT NOT NULL,

  FOREIGN KEY(question_id) REFERENCES questions(id)
  FOREIGN KEY(reply_author) REFERENCES users(id)
  FOREIGN KEY(parent_id) REFERENCES replies(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(question_id) REFERENCES questions(id)
);

INSERT INTO
    users (fname, lname)
VALUES
  ("Chris", "Tsai");

INSERT INTO
  users (fname, lname)
VALUES
  ("Atai", "Chynaliev");

INSERT INTO
  questions (title, body, author_id)
VALUES
  ("Whatsup?", "Whatsgoing on dog?", (SELECT id FROM users WHERE fname = 'Chris'));
