// Voice Lines: a small page for writing training lines into Supabase.
// The key below is the project's *publishable* key: it is meant to be public. What a
// signed-in writer can see and change is decided by row-level security in the database,
// not by this page.
(function () {
  var CONFIG = window.VOICE_LINES_CONFIG || {
    url: 'https://cmiotfsijbzleqlwbldg.supabase.co',
    key: 'sb_publishable_HuKCmb2rJ8nwsJdva9Kgmw__1wiY2AB'
  };
  var R = window.VoiceRules;
  var $ = function (id) { return document.getElementById(id); };
  var db = window.__client || window.supabase.createClient(CONFIG.url, CONFIG.key, {
    auth: { persistSession: true, detectSessionInUrl: true }
  });

  var mine = [];          // this writer's lines
  var editing = null;     // id of the line being edited
  var user = null;

  function fill(select, values) {
    values.forEach(function (v) {
      var o = document.createElement('option');
      o.value = v; o.textContent = v;
      select.appendChild(o);
    });
  }
  fill($('voice'), R.TONES);
  fill($('length'), R.LENGTHS);
  fill($('moment'), R.MOMENTS);
  $('length').value = 'measured';
  $('moment').value = 'chat';

  function remember() {
    try {
      localStorage.setItem('voiceLines.writtenBy', $('writtenBy').value);
      localStorage.setItem('voiceLines.rights', $('rights').value);
    } catch (e) { /* private window: fine */ }
  }
  try {
    $('writtenBy').value = localStorage.getItem('voiceLines.writtenBy') || '';
    $('rights').value = localStorage.getItem('voiceLines.rights') || 'own';
  } catch (e) { /* no storage */ }

  function say(text, kind) {
    var m = $('message');
    m.textContent = text || '';
    m.className = kind || '';
  }

  function entry() {
    var moment = $('moment').value;
    return {
      voice: $('voice').value,
      length: $('length').value,
      moment: moment,
      author_line: (moment === 'opening' || moment === 'returning') ? '' : $('said').value.trim(),
      reply: $('reply').value.trim()
    };
  }

  function refresh() {
    var moment = $('moment').value;
    var hasSaid = moment === 'chat' || moment === 'farewell';
    $('said-wrap').classList.toggle('hidden', !hasSaid);
    $('count').textContent = R.words($('reply').value) + ' words';
    var e = entry();
    var typed = $('reply').value.trim() || $('said').value.trim();
    var problems = typed ? R.validate(e) : [];
    var list = $('problems');
    list.textContent = '';
    problems.forEach(function (p) {
      var li = document.createElement('li');
      li.textContent = p;
      list.appendChild(li);
    });
    var valid = R.validate(e).length === 0 && $('reply').value.trim() !== '';
    if (valid) {
      var ok = document.createElement('li');
      ok.className = 'ok';
      ok.textContent = 'This line follows the rules.';
      list.appendChild(ok);
    }
    $('add').disabled = !(valid && $('writtenBy').value.trim() && $('human').checked);
  }
  ['voice', 'length', 'moment', 'said', 'reply', 'writtenBy', 'rights', 'human'].forEach(function (id) {
    $(id).addEventListener('input', refresh);
    $(id).addEventListener('change', refresh);
  });
  $('writtenBy').addEventListener('change', remember);
  $('rights').addEventListener('change', remember);

  function coverage() {
    var counts = {};
    mine.forEach(function (l) {
      var k = l.voice + '|' + l.moment;
      counts[k] = (counts[k] || 0) + 1;
    });
    var t = $('coverage');
    t.textContent = '';
    var head = t.insertRow();
    ['voice'].concat(R.MOMENTS).forEach(function (h) {
      var th = document.createElement('th');
      th.textContent = h === 'voice' ? 'Voice' : h + ' (' + R.TARGETS[h] + ')';
      head.appendChild(th);
    });
    R.TONES.forEach(function (tone) {
      var row = t.insertRow();
      row.insertCell().textContent = tone;
      R.MOMENTS.forEach(function (m) {
        var n = counts[tone + '|' + m] || 0;
        var c = row.insertCell();
        c.textContent = n;
        c.className = n >= R.TARGETS[m] ? 'met' : 'short';
      });
    });
  }

  function render() {
    coverage();
    var box = $('lines');
    box.textContent = '';
    if (!mine.length) {
      var p = document.createElement('p');
      p.className = 'hint';
      p.textContent = 'Nothing yet. Add your first line above.';
      box.appendChild(p);
      return;
    }
    mine.forEach(function (l) {
      var div = document.createElement('div');
      div.className = 'line';
      var tags = document.createElement('div');
      tags.className = 'tags';
      [l.voice, l.length, l.moment, l.status].forEach(function (t, i) {
        var s = document.createElement('span');
        s.className = 'chip' + (i === 3 ? ' ' + l.status : '');
        s.textContent = t;
        tags.appendChild(s);
      });
      div.appendChild(tags);
      if (l.author_line) {
        var said = document.createElement('div');
        said.className = 'said';
        said.textContent = '“' + l.author_line + '”';
        div.appendChild(said);
      }
      var reply = document.createElement('div');
      reply.textContent = l.reply;
      div.appendChild(reply);
      if (l.status === 'submitted') {
        var tools = document.createElement('div');
        tools.className = 'tools';
        var edit = document.createElement('button');
        edit.className = 'link'; edit.type = 'button'; edit.textContent = 'Edit';
        edit.addEventListener('click', function () { startEdit(l); });
        var del = document.createElement('button');
        del.className = 'link'; del.type = 'button'; del.textContent = 'Remove';
        del.addEventListener('click', function () { remove(l); });
        tools.appendChild(edit); tools.appendChild(del);
        div.appendChild(tools);
      }
      box.appendChild(div);
    });
  }

  async function load() {
    var res = await db.from('training_lines').select('*').order('created_at', { ascending: false });
    if (res.error) { say('Could not load your lines: ' + res.error.message, 'err'); return; }
    mine = res.data || [];
    render();
  }

  function startEdit(l) {
    editing = l.id;
    $('voice').value = l.voice; $('length').value = l.length; $('moment').value = l.moment;
    $('said').value = l.author_line; $('reply').value = l.reply;
    $('add').textContent = 'Save changes';
    say('Editing a line. Change it and save.', '');
    $('reply').focus();
    refresh();
  }

  async function remove(l) {
    if (!confirm('Remove this line?')) return;
    var res = await db.from('training_lines').delete().eq('id', l.id);
    if (res.error) { say('Could not remove it: ' + res.error.message, 'err'); return; }
    say('Removed.', 'ok');
    await load();
  }

  $('form').addEventListener('submit', async function (ev) {
    ev.preventDefault();
    var e = entry();
    if (R.validate(e).length) { refresh(); return; }
    remember();
    $('add').disabled = true;
    var res;
    if (editing) {
      res = await db.from('training_lines').update(e).eq('id', editing);
    } else {
      res = await db.from('training_lines').insert(Object.assign({
        written_by: $('writtenBy').value.trim(),
        rights: $('rights').value,
        ai_assisted: false
      }, e));
    }
    if (res.error) {
      var dup = /duplicate|unique/i.test(res.error.message);
      say(dup ? 'You already have that exact line.' : 'Could not save it: ' + res.error.message, 'err');
      refresh();
      return;
    }
    say(editing ? 'Saved.' : 'Added. It will be used once it has been reviewed.', 'ok');
    editing = null;
    $('add').textContent = 'Add line';
    $('reply').value = ''; $('said').value = '';
    $('human').checked = false;
    refresh();
    await load();
    $('reply').focus();
  });

  $('send').addEventListener('click', async function () {
    var email = $('email').value.trim();
    var m = $('signin-message');
    if (!/^\S+@\S+\.\S+$/.test(email)) { m.textContent = 'Enter your email address.'; return; }
    $('send').disabled = true;
    var res = await db.auth.signInWithOtp({
      email: email,
      options: { emailRedirectTo: window.location.href.split('#')[0] }
    });
    $('send').disabled = false;
    m.textContent = res.error ? 'Could not send it: ' + res.error.message
                              : 'Check your email for the link.';
  });

  $('signout').addEventListener('click', async function () { await db.auth.signOut(); });

  function show(session) {
    user = session ? session.user : null;
    $('signin').classList.toggle('hidden', !!user);
    $('app').classList.toggle('hidden', !user);
    if (user) {
      $('who-email').textContent = user.email || 'signed in';
      refresh();
      load();
    } else {
      mine = [];
      render();
    }
  }
  db.auth.onAuthStateChange(function (_event, session) { show(session); });
  db.auth.getSession().then(function (r) { show(r.data.session); });
  refresh();
})();
