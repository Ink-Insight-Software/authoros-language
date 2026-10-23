// The same rules as model/authoring.py and the database: what a line may contain.
// Kept in its own file so it can be tested without a browser.
(function (root) {
  var TONES = ['neutral', 'warm', 'gentle', 'earnest', 'dry', 'sardonic', 'blunt', 'formal',
               'timid', 'quiet', 'playful', 'stoic'];
  var LENGTHS = ['terse', 'measured', 'expansive'];
  var MOMENTS = ['opening', 'returning', 'chat', 'farewell'];
  var TARGETS = { opening: 10, returning: 10, chat: 40, farewell: 10 };
  var MAX_REPLY_WORDS = 30, MAX_AUTHOR_WORDS = 40;

  var MARKUP = /[*#`_>|\[\]{}<>\\]|^\s*[-•]\s/;
  var QUOTES = /["“”]/;
  var TITLES = /\b(?:Mr|Mrs|Miss|Ms|Dr|Sir|Madam|Lady|Lord)\b\.?/;

  function words(text) {
    var t = text.trim();
    return t ? t.split(/\s+/).length : 0;
  }

  // Capitalised words that do not begin a sentence, apart from "I".
  function midSentenceCapitals(text) {
    var out = [], re = /[A-Za-z][A-Za-z'’-]*/g, m;
    while ((m = re.exec(text))) {
      var w = m[0];
      if (w === 'I' || w.indexOf("I'") === 0 || w.indexOf('I’') === 0) continue;
      if (w[0] === w[0].toLowerCase()) continue;
      var head = text.slice(0, m.index).replace(/\s+$/, '');
      if (!head || /[.!?…]$/.test(head) || /(?:—|-|"|“)$/.test(head)) continue;
      out.push(w);
    }
    return out;
  }

  // Problems with one line of text; `what` is "reply" or "author line".
  function check(text, what) {
    var bad = [], n = words(text), limit = what === 'reply' ? MAX_REPLY_WORDS : MAX_AUTHOR_WORDS;
    if (!text.trim()) return [what + ' is empty'];
    if (/[\r\n]/.test(text)) bad.push(what + ' must be one line');
    if (n > limit) bad.push(what + ' is ' + n + ' words; the limit is ' + limit);
    if (MARKUP.test(text)) bad.push(what + ' has markup or a list marker');
    if (/\d/.test(text)) bad.push(what + ' has a digit; write numbers as words or leave them out');
    if (QUOTES.test(text)) bad.push(what + ' has quotation marks');
    var caps = midSentenceCapitals(text);
    if (TITLES.test(text) || caps.length) {
      bad.push(what + ' seems to name someone or somewhere (' + (caps.join(', ') || 'a title') +
               '); characters are not given names here');
    }
    return bad;
  }

  // All problems with a whole entry.
  function validate(e) {
    var bad = [];
    if (TONES.indexOf(e.voice) < 0) bad.push('choose a voice');
    if (LENGTHS.indexOf(e.length) < 0) bad.push('choose how much they say');
    if (MOMENTS.indexOf(e.moment) < 0) bad.push('choose a moment');
    var hasSaid = e.moment === 'chat' || e.moment === 'farewell';
    if (hasSaid && e.moment === 'chat' && !(e.author_line || '').trim()) {
      bad.push('a chat line needs what the author says');
    }
    if (hasSaid && (e.author_line || '').trim()) bad = bad.concat(check(e.author_line, 'author line'));
    return bad.concat(check(e.reply || '', 'reply'));
  }

  root.VoiceRules = {
    TONES: TONES, LENGTHS: LENGTHS, MOMENTS: MOMENTS, TARGETS: TARGETS,
    words: words, check: check, validate: validate, midSentenceCapitals: midSentenceCapitals
  };
  if (typeof module !== 'undefined') module.exports = root.VoiceRules;
})(typeof window !== 'undefined' ? window : globalThis);
