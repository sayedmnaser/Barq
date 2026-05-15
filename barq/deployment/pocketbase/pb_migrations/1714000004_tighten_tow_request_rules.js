/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");
    const listView =
      '@request.auth.id != "" && (' +
      'user = @request.auth.id || ' +
      'driver = @request.auth.id || ' +
      '(@request.auth.Driver = true && status = "pending" && ' +
      '(candidate_drivers:length = 0 || candidate_drivers.id ?= @request.auth.id))' +
      ')';
    const update =
      '@request.auth.id != "" && (' +
      'user = @request.auth.id || ' +
      'driver = @request.auth.id || ' +
      '(@request.auth.Driver = true && status = "pending" && driver = "" && ' +
      '(candidate_drivers:length = 0 || candidate_drivers.id ?= @request.auth.id))' +
      ')';
    c.listRule = listView;
    c.viewRule = listView;
    c.updateRule = update;
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");
    const r =
      '@request.auth.id != "" && (user = @request.auth.id || driver = @request.auth.id || @request.auth.Driver = true)';
    c.listRule = r;
    c.viewRule = r;
    c.updateRule = r;
    app.save(c);
  }
);
