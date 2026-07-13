/// A session should be queued to the local pending-sync table whenever
/// the Firestore write did not succeed, regardless of why (device is
/// offline, or the write threw for some other transient reason).
///
/// [isOnline] is accepted for readability at call sites even though the
/// logic collapses to `!writeSucceeded` -- a failed write must always be
/// queued whether or not the device *currently* reports online, since a
/// reported-online write can still fail (a Firestore permission hiccup,
/// or a captive-portal wifi false positive from connectivity_plus).
bool shouldQueueGameSessionOffline({
  required bool isOnline,
  required bool writeSucceeded,
}) =>
    !writeSucceeded;
