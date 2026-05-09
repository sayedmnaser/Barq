const pendingRequestTtlMs = 15 * 60 * 1000;

cronAdd("cleanupPendingTowRequests", "*/1 * * * *", () => {
  const cutoff = new Date(Date.now() - pendingRequestTtlMs).toISOString();

  while (true) {
    const records = $app.findRecordsByFilter(
      "tow_requests",
      "status = 'pending' && created <= {:cutoff}",
      "created",
      100,
      0,
      { cutoff: cutoff }
    );

    if (records.length === 0) {
      break;
    }

    for (const record of records) {
      try {
        $app.delete(record);
      } catch (err) {
        console.log(`Could not delete expired tow request ${record.id}: ${err}`);
      }
    }
  }
});
