-- Upgrade a 0.4.x database to 0.5.0 (replying back). Run once.

-- Local replies look up the remote reply they answer by the host's id for it.
ALTER TABLE `ApRemoteObject` ADD KEY `IX_ApRemoteObject_HostId` (`HostId`);
