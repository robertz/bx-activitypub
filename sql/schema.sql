-- bx-activitypub schema. MySQL 8.0.13+ (UUID_TO_BIN, expression defaults).
-- Ap* tables only; the module never reads or writes the host app's tables.

CREATE TABLE IF NOT EXISTS `ApActorKey` (
	`ActorType`     VARCHAR(16)  NOT NULL,
	`LocalId`       BINARY(16)   NOT NULL,
	`PublicKeyPem`  TEXT         NOT NULL,
	`PrivateKeyPem` TEXT         NOT NULL,
	`CreatedAt`     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
	PRIMARY KEY (`ActorType`, `LocalId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ApRemoteActor` (
	`Id`             BINARY(16)    NOT NULL DEFAULT (UUID_TO_BIN(UUID())),
	`ActorUrl`       VARCHAR(512)  NOT NULL,
	`InboxUrl`       VARCHAR(512)  NOT NULL,
	`SharedInboxUrl` VARCHAR(512)  DEFAULT NULL,
	`PublicKeyId`    VARCHAR(512)  NOT NULL,
	`PublicKeyPem`   TEXT          NOT NULL,
	`Name`           VARCHAR(255)  DEFAULT NULL,
	`Handle`         VARCHAR(255)  DEFAULT NULL,
	`ProfileUrl`     VARCHAR(512)  DEFAULT NULL,
	`AvatarUrl`      VARCHAR(512)  DEFAULT NULL,
	`FetchedAt`      DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
	PRIMARY KEY (`Id`),
	UNIQUE KEY `UX_ApRemoteActor_ActorUrl` (`ActorUrl`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ApFollower` (
	`Id`               BINARY(16)    NOT NULL DEFAULT (UUID_TO_BIN(UUID())),
	`ActorType`        VARCHAR(16)   NOT NULL,
	`LocalId`          BINARY(16)    NOT NULL,
	`RemoteActorId`    BINARY(16)    NOT NULL,
	`InboxUrl`         VARCHAR(512)  NOT NULL,
	`SharedInboxUrl`   VARCHAR(512)  DEFAULT NULL,
	`FollowActivityId` VARCHAR(512)  NOT NULL,
	`CreatedAt`        DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
	PRIMARY KEY (`Id`),
	UNIQUE KEY `UX_ApFollower_Local_Remote` (`ActorType`, `LocalId`, `RemoteActorId`),
	CONSTRAINT `FK_ApFollower_ApRemoteActor` FOREIGN KEY (`RemoteActorId`) REFERENCES `ApRemoteActor` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Json is TEXT, not JSON: MySQL's JSON type re-orders keys, and the stored string is what gets signed and served.
CREATE TABLE IF NOT EXISTS `ApActivity` (
	`Id`        BINARY(16)    NOT NULL,
	`Type`      VARCHAR(32)   NOT NULL,
	`ActorUrl`  VARCHAR(512)  NOT NULL,
	`ObjectUrl` VARCHAR(512)  DEFAULT NULL,
	`Json`      MEDIUMTEXT    NOT NULL,
	`CreatedAt` DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
	PRIMARY KEY (`Id`),
	KEY `IX_ApActivity_Object` (`ObjectUrl`, `Type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ClaimToken lets several app instances share the queue: a worker claims rows with one
-- UPDATE ... LIMIT, then reads back only its own token. NextAttemptAt NULL = finished (delivered or given up).
CREATE TABLE IF NOT EXISTS `ApDelivery` (
	`Id`              BINARY(16)    NOT NULL DEFAULT (UUID_TO_BIN(UUID())),
	`ActivityId`      BINARY(16)    NOT NULL,
	`SigningActorType` VARCHAR(16) NOT NULL,
	`SigningLocalId`  BINARY(16)    NOT NULL,
	`SigningKeyId`    VARCHAR(512)  NOT NULL,
	`InboxUrl`        VARCHAR(512)  NOT NULL,
	`Attempts`        INT           NOT NULL DEFAULT 0,
	`NextAttemptAt`   DATETIME(3)   DEFAULT CURRENT_TIMESTAMP(3),
	`ClaimToken`      BINARY(16)    DEFAULT NULL,
	`LastStatus`      INT           DEFAULT NULL,
	`LastError`       VARCHAR(1024) DEFAULT NULL,
	`DeliveredAt`     DATETIME(3)   DEFAULT NULL,
	PRIMARY KEY (`Id`),
	KEY `IX_ApDelivery_Due` (`NextAttemptAt`),
	KEY `IX_ApDelivery_Claim` (`ClaimToken`),
	CONSTRAINT `FK_ApDelivery_ApActivity` FOREIGN KEY (`ActivityId`) REFERENCES `ApActivity` (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Remote objects the host accepted (0.2.0: replies to local posts), mapped to the host's own
-- id for them, so edits, deletes and replies-to-replies find the right record.
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
	KEY `IX_ApRemoteObject_ActorUrl` (`ActorUrl`),
	KEY `IX_ApRemoteObject_HostId` (`HostId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
