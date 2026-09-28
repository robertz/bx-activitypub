-- Upgrade a 0.1.x database to 0.2.0 (replies from the fediverse). Run once.

ALTER TABLE `ApRemoteActor`
	ADD COLUMN `Name`       VARCHAR(255) DEFAULT NULL AFTER `PublicKeyPem`,
	ADD COLUMN `Handle`     VARCHAR(255) DEFAULT NULL AFTER `Name`,
	ADD COLUMN `ProfileUrl` VARCHAR(512) DEFAULT NULL AFTER `Handle`,
	ADD COLUMN `AvatarUrl`  VARCHAR(512) DEFAULT NULL AFTER `ProfileUrl`;

CREATE TABLE IF NOT EXISTS `ApRemoteObject` (
	`Id`            BINARY(16)    NOT NULL DEFAULT (UUID_TO_BIN(UUID())),
	`ObjectUrl`     VARCHAR(512)  NOT NULL,
	`ActorUrl`      VARCHAR(512)  NOT NULL,
	`LocalPostId`   VARCHAR(64)   NOT NULL,
	`HostId`        VARCHAR(64)   NOT NULL,
	`CreatedAt`     DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
	`UpdatedAt`     DATETIME(3)   DEFAULT NULL,
	PRIMARY KEY (`Id`),
	UNIQUE KEY `UX_ApRemoteObject_ObjectUrl` (`ObjectUrl`),
	KEY `IX_ApRemoteObject_ActorUrl` (`ActorUrl`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
