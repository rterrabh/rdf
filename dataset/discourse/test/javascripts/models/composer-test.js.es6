import { blank } from 'helpers/qunit-helpers';
import { currentUser } from 'helpers/qunit-helpers';

module("model:composer");

function createComposer(opts) {
  opts = opts || {};
  opts.user = opts.user || currentUser();
  opts.site = Discourse.Site.current();
  opts.siteSettings = Discourse.SiteSettings;
  return Discourse.Composer.create(opts);
}

test('replyLength', function() {
  const replyLength = function(val, expectedLength) {
    const composer = createComposer({ reply: val });
    equal(composer.get('replyLength'), expectedLength);
  };

  replyLength("basic reply", 11, "basic reply length");
  replyLength(" \nbasic reply\t", 11, "trims whitespaces");
  replyLength("ba sic\n\nreply", 12, "count only significant whitespaces");
  replyLength("1[quote=]not counted[/quote]2[quote=]at all[/quote]3", 3, "removes quotes");
  replyLength("1[quote=]not[quote=]counted[/quote]yay[/quote]2", 2, "handles nested quotes correctly");
});

test('missingReplyCharacters', function() {
  Discourse.SiteSettings.min_first_post_length = 40;
  const missingReplyCharacters = function(val, isPM, isFirstPost, expected, message) {
    const composer = createComposer({ reply: val, creatingPrivateMessage: isPM, creatingTopic: isFirstPost });
    equal(composer.get('missingReplyCharacters'), expected, message);
  };

  missingReplyCharacters('hi', false, false, Discourse.SiteSettings.min_post_length - 2, 'too short public post');
  missingReplyCharacters('hi', false, true,  Discourse.SiteSettings.min_first_post_length - 2, 'too short first post');
  missingReplyCharacters('hi', true, false,  Discourse.SiteSettings.min_private_message_post_length - 2, 'too short private message');
});

test('missingTitleCharacters', function() {
  const missingTitleCharacters = function(val, isPM, expected, message) {
    const composer = createComposer({ title: val, creatingPrivateMessage: isPM });
    equal(composer.get('missingTitleCharacters'), expected, message);
  };

  missingTitleCharacters('hi', false, Discourse.SiteSettings.min_topic_title_length - 2, 'too short post title');
  missingTitleCharacters('z', true,  Discourse.SiteSettings.min_private_message_title_length - 1, 'too short pm title');
});

test('replyDirty', function() {
  const composer = createComposer();
  ok(!composer.get('replyDirty'), "by default it's false");

  composer.setProperties({
    originalText: "hello",
    reply: "hello"
  });

  ok(!composer.get('replyDirty'), "it's false when the originalText is the same as the reply");
  composer.set('reply', 'hello world');
  ok(composer.get('replyDirty'), "it's true when the reply changes");
});

test("appendText", function() {
  const composer = createComposer();

  blank(composer.get('reply'), "the reply is blank by default");

  composer.appendText("hello");
  equal(composer.get('reply'), "hello", "it appends text to nothing");
  composer.appendText(" world");
  equal(composer.get('reply'), "hello world", "it appends text to existing text");

  composer.clearState();
  composer.appendText("a\n\n\n\nb");
  composer.appendText("c",3,{block: true});

  equal(composer.get("reply"), "a\n\nc\n\nb");

  composer.clearState();
  composer.appendText("ab");
  composer.appendText("c",1,{block: true});

  equal(composer.get("reply"), "a\n\nc\n\nb");

  composer.clearState();
  composer.appendText("\nab");
  composer.appendText("c",0,{block: true});

  equal(composer.get("reply"), "c\n\nab");
});

test("Title length for regular topics", function() {
  Discourse.SiteSettings.min_topic_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer();

  composer.set('title', 'asdf');
  ok(!composer.get('titleLengthValid'), "short titles are not valid");

  composer.set('title', 'this is a long title');
  ok(!composer.get('titleLengthValid'), "long titles are not valid");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");
});

test("Title length for private messages", function() {
  Discourse.SiteSettings.min_private_message_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer({action: Discourse.Composer.PRIVATE_MESSAGE});

  composer.set('title', 'asdf');
  ok(!composer.get('titleLengthValid'), "short titles are not valid");

  composer.set('title', 'this is a long title');
  ok(!composer.get('titleLengthValid'), "long titles are not valid");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");
});

test("Title length for private messages", function() {
  Discourse.SiteSettings.min_private_message_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer({action: Discourse.Composer.PRIVATE_MESSAGE});

  composer.set('title', 'asdf');
  ok(!composer.get('titleLengthValid'), "short titles are not valid");

  composer.set('title', 'this is a long title');
  ok(!composer.get('titleLengthValid'), "long titles are not valid");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");
});

test('editingFirstPost', function() {
  const composer = createComposer();
  ok(!composer.get('editingFirstPost'), "it's false by default");

  const post = Discourse.Post.create({id: 123, post_number: 2});
  composer.setProperties({post: post, action: Discourse.Composer.EDIT });
  ok(!composer.get('editingFirstPost'), "it's false when not editing the first post");

  post.set('post_number', 1);
  ok(composer.get('editingFirstPost'), "it's true when editing the first post");

});

test('clearState', function() {
  const composer = createComposer({
    originalText: 'asdf',
    reply: 'asdf2',
    post: Discourse.Post.create({id: 1}),
    title: 'wat'
  });

  composer.clearState();

  blank(composer.get('originalText'));
  blank(composer.get('reply'));
  blank(composer.get('post'));
  blank(composer.get('title'));

});

test('initial category when uncategorized is allowed', function() {
  Discourse.SiteSettings.allow_uncategorized_topics = true;
  const composer = Discourse.Composer.open({action: 'createTopic', draftKey: 'asfd', draftSequence: 1});
  equal(composer.get('categoryId'),undefined,"Uncategorized by default");
});

test('initial category when uncategorized is not allowed', function() {
  Discourse.SiteSettings.allow_uncategorized_topics = false;
  const composer = Discourse.Composer.open({action: 'createTopic', draftKey: 'asfd', draftSequence: 1});
  ok(composer.get('categoryId') === undefined, "Uncategorized by default. Must choose a category.");
});

test('showPreview', function() {
  const newComposer = function() {
    return Discourse.Composer.open({action: 'createTopic', draftKey: 'asfd', draftSequence: 1});
  };

  Discourse.Mobile.mobileView = true;
  equal(newComposer().get('showPreview'), false, "Don't show preview in mobile view");

  Discourse.KeyValueStore.set({ key: 'composer.showPreview', value: 'true' });
  equal(newComposer().get('showPreview'), false, "Don't show preview in mobile view even if KeyValueStore wants to");
  Discourse.KeyValueStore.remove('composer.showPreview');

  Discourse.Mobile.mobileView = false;
  equal(newComposer().get('showPreview'), true, "Show preview by default in desktop view");
});

test('open with a quote', function() {
  const quote = '[quote="neil, post:5, topic:413"]\nSimmer down you two.\n[/quote]';
  const newComposer = function() {
    return Discourse.Composer.open({action: Discourse.Composer.REPLY, draftKey: 'asfd', draftSequence: 1, quote: quote});
  };

  equal(newComposer().get('originalText'), quote, "originalText is the quote" );
  equal(newComposer().get('replyDirty'), false, "replyDirty is initally false with a quote" );
});

test("Title length for static page topics as admin", function() {
  Discourse.SiteSettings.min_topic_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer();

  const post = Discourse.Post.create({id: 123, post_number: 2, static_doc: true});
  composer.setProperties({post: post, action: Discourse.Composer.EDIT });

  composer.set('title', 'asdf');
  ok(composer.get('titleLengthValid'), "admins can use short titles");

  composer.set('title', 'this is a long title');
  ok(composer.get('titleLengthValid'), "admins can use long titles");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");

  composer.set('title', '');
  ok(!composer.get('titleLengthValid'), "admins must set title to at least 1 character");
});
