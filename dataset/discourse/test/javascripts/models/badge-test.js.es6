import Badge from 'discourse/models/badge';

module("model:badge");

test('newBadge', function() {
  const badge1 = Badge.create({name: "New Badge"}),
      badge2 = Badge.create({id: 1, name: "Old Badge"});
  ok(badge1.get('newBadge'), "badges without ids are new");
  ok(!badge2.get('newBadge'), "badges with ids are not new");
});

test('displayName', function() {
  const badge1 = Badge.create({id: 1, name: "Test Badge 1"});
  equal(badge1.get('displayName'), "Test Badge 1", "falls back to the original name in the absence of a translation");

  sandbox.stub(I18n, "t").returnsArg(0);
  const badge2 = Badge.create({id: 2, name: "Test Badge 2"});
  equal(badge2.get('displayName'), "badges.badge.test_badge_2.name", "uses translation when available");
});

test('translatedDescription', function() {
  const badge1 = Badge.create({id: 1, name: "Test Badge 1", description: "TEST"});
  equal(badge1.get('translatedDescription'), null, "returns null when no translation exists");

  const badge2 = Badge.create({id: 2, name: "Test Badge 2 **"});
  sandbox.stub(I18n, "t").returns("description translation");
  equal(badge2.get('translatedDescription'), "description translation", "users translated description");
});

test('displayDescription', function() {
  const badge1 = Badge.create({id: 1, name: "Test Badge 1", description: "TEST"});
  equal(badge1.get('displayDescription'), "TEST", "returns original description when no translation exists");

  const badge2 = Badge.create({id: 2, name: "Test Badge 2 **"});
  sandbox.stub(I18n, "t").returns("description translation");
  equal(badge2.get('displayDescription'), "description translation", "users translated description");
});

test('createFromJson array', function() {
  const badgesJson = {"badge_types":[{"id":6,"name":"Silver 1"}],"badges":[{"id":1126,"name":"Badge 1","description":null,"badge_type_id":6}]};

  const badges = Badge.createFromJson(badgesJson);

  ok(Array.isArray(badges), "returns an array");
  equal(badges[0].get('name'), "Badge 1", "badge details are set");
  equal(badges[0].get('badge_type.name'), "Silver 1", "badge_type reference is set");
});

test('createFromJson single', function() {
  const badgeJson = {"badge_types":[{"id":6,"name":"Silver 1"}],"badge":{"id":1126,"name":"Badge 1","description":null,"badge_type_id":6}};

  const badge = Badge.createFromJson(badgeJson);

  ok(!Array.isArray(badge), "does not returns an array");
});

test('updateFromJson', function() {
  const badgeJson = {"badge_types":[{"id":6,"name":"Silver 1"}],"badge":{"id":1126,"name":"Badge 1","description":null,"badge_type_id":6}};
  const badge = Badge.create({name: "Badge 1"});
  badge.updateFromJson(badgeJson);
  equal(badge.get('id'), 1126, "id is set");
  equal(badge.get('badge_type.name'), "Silver 1", "badge_type reference is set");
});

test('save', function() {
  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve({}));
  const badge = Badge.create({name: "New Badge", description: "This is a new badge.", badge_type_id: 1});
  // TODO: clean API
  badge.save(["name", "description", "badge_type_id"]);
  ok(Discourse.ajax.calledOnce, "saved badge");
});

test('destroy', function() {
  sandbox.stub(Discourse, 'ajax');
  const badge = Badge.create({name: "New Badge", description: "This is a new badge.", badge_type_id: 1});
  badge.destroy();
  ok(!Discourse.ajax.calledOnce, "no AJAX call for a new badge");
  badge.set('id', 3);
  badge.destroy();
  ok(Discourse.ajax.calledOnce, "AJAX call was made");
});
