-- Upgrade a 0.5.x database to 0.6.0 (whole threads). Run once.

-- Walk state for fetching replies further down fediverse threads (Threads.bx). Existing
-- replies start due, so the first run walks them (and learns their RepliesUrl).
ALTER TABLE `ApRemoteObject`
	ADD COLUMN `ParentUrl`    VARCHAR(512) DEFAULT NULL AFTER `HostId`,
	ADD COLUMN `RepliesUrl`   VARCHAR(512) DEFAULT NULL AFTER `ParentUrl`,
	ADD COLUMN `Depth`        TINYINT      NOT NULL DEFAULT 0 AFTER `RepliesUrl`,
	ADD COLUMN `Fetched`      TINYINT(1)   NOT NULL DEFAULT 0 AFTER `Depth`,
	ADD COLUMN `NextWalkAt`   DATETIME(3)  DEFAULT NULL AFTER `Fetched`,
	ADD COLUMN `WalkFailures` INT          NOT NULL DEFAULT 0 AFTER `NextWalkAt`,
	ADD COLUMN `WalkToken`    BINARY(16)   DEFAULT NULL AFTER `WalkFailures`,
	ADD KEY `IX_ApRemoteObject_Parent` (`ParentUrl`(255)),
	ADD KEY `IX_ApRemoteObject_NextWalk` (`NextWalkAt`);

UPDATE `ApRemoteObject` SET `NextWalkAt` = NOW(3);
