CREATE TABLE users (
	seq INT(20) NOT NULL auto_increment,
	signup VARCHAR(10) NOT NULL,
	priv INT(2) NOT NULL,
	uname VARCHAR(12) NOT NULL,
	sec VARCHAR(32) NOT NULL,
	theme INT(1) DEFAULT NULL,
	fn VARCHAR(12) DEFAULT NULL,
	ln VARCHAR(20) DEFAULT NULL,
	cc CHAR(2) NOT NULL,
	email VARCHAR(128) NOT NULL,
	femail VARCHAR(128) DEFAULT NULL,
	url VARCHAR(255) DEFAULT NULL,
	PRIMARY KEY(seq),
	UNIQUE KEY uname (uname),
	UNIQUE KEY email (email)
) TYPE=MyISAM;

INSERT INTO users VALUES('',NOW(),99,'sysop',MD5('newpass'),'','','','US','root@localhost','','');

CREATE TABLE screens (
	seq INT(20) NOT NULL auto_increment,
	author VARCHAR(32),
	file VARCHAR(32) NOT NULL,
	id VARCHAR(12) NOT NULL,
	PRIMARY KEY(seq),
	UNIQUE KEY id (id)
) TYPE=MyISAM;

INSERT INTO screens VALUES('','x86','login.ans','login');
