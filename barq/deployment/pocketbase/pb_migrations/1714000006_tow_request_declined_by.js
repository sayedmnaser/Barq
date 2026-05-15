/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");

    c.fields.add(
      new RelationField({
        id: "rel_tow_declined_by",
        name: "declined_by",
        collectionId: "_pb_users_auth_",
        cascadeDelete: false,
        maxSelect: 999,
        minSelect: 0,
        required: false,
      })
    );

    const listView =
      '@request.auth.id != "" && (' +
      'user = @request.auth.id || ' +
      'driver = @request.auth.id || ' +
      '(@request.auth.Driver = true && status = "pending" && ' +
      '(candidate_drivers:length = 0 || candidate_drivers.id ?= @request.auth.id) && ' +
      '!(declined_by.id ?= @request.auth.id))' +
      ')';
    const update =
      '@request.auth.id != "" && (' +
      'user = @request.auth.id || ' +
      'driver = @request.auth.id || ' +
      '(@request.auth.Driver = true && status = "pending" && driver = "" && ' +
      '(candidate_drivers:length = 0 || candidate_drivers.id ?= @request.auth.id) && ' +
      '!(declined_by.id ?= @request.auth.id))' +
      ')';
    c.listRule = listView;
    c.viewRule = listView;
    c.updateRule = update;
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");
    const declined = c.fields.getByName("declined_by");
    if (declined) {
      c.fields.removeById(declined.id);
    }
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
  }
);
