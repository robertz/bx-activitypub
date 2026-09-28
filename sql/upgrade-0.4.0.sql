-- Upgrade a 0.2.x/0.3.x database to 0.4.0 (likes and boosts). Run once.

-- Likes and boosts (Announce) of local objects, one per actor per type per object (0.4.0).
CREATE TABLE IF NOT EXISTS `ApReaction` (
	`Id`         BINARY(16)    NOT NULL DEFAULT (UUID_TO_BIN(UUID())),
	`Type`       VARCHAR(16)   NOT NULL,
	`ActorUrl`   VARCHAR(512)  NOT NULL,
	`ObjectUrl`  VARCHAR(512)  NOT NULL,
	`ActivityId` VARCHAR(512)  NOT NULL,
	`CreatedAt`  DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
	PRIMARY KEY (`Id`),
	UNIQUE KEY `UX_ApReaction_Actor_Type_Object` (`ActorUrl`(255), `Type`, `ObjectUrl`(255)),
	KEY `IX_ApReaction_Object` (`ObjectUrl`(255), `Type`),
	KEY `IX_ApReaction_Activity` (`ActivityId`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
