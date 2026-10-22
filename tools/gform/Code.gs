// gform web app: creates a Google Form and the Sheet its responses go to, from a JSON spec.
// Deployed to execute as the deploying account, so that account owns everything it creates.
// Every request must carry the token stored in the TOKEN script property.

var QUESTION_TYPES = {
  text: 1, paragraph: 1, choice: 1, checkbox: 1, dropdown: 1, scale: 1,
  date: 1, time: 1, datetime: 1, grid: 1, checkbox_grid: 1,
};
var LAYOUT_TYPES = { section: 1, page: 1 };
var TEXT_VALIDATIONS = { email: 1, number: 1, url: 1 };

function doPost(e) {
  var out;
  try {
    var req = JSON.parse(e.postData.contents);
    checkToken(req.token);
    if (req.action === 'ping') out = { ok: true, account: account() };
    else if (req.action === 'create') out = create(req);
    else throw new Error('unknown action: ' + req.action);
  } catch (err) {
    out = { ok: false, error: String((err && err.message) || err) };
  }
  return ContentService.createTextOutput(JSON.stringify(out))
    .setMimeType(ContentService.MimeType.JSON);
}

function checkToken(token) {
  var expected = PropertiesService.getScriptProperties().getProperty('TOKEN');
  if (!expected) throw new Error('the TOKEN script property is not set');
  if (token !== expected) throw new Error('bad token');
}

function account() {
  return Session.getEffectiveUser().getEmail();
}

function create(req) {
  var spec = req.spec;
  validate(spec);

  var form = FormApp.create(spec.title);
  // Files this request made, trashed again if a later step fails.
  var made = [form.getId()];
  try {
    if (spec.description) form.setDescription(spec.description);
    if (spec.confirmation) form.setConfirmationMessage(spec.confirmation);
    if (spec.collect_email) form.setCollectEmail(true);
    if (spec.one_response_per_user) form.setLimitOneResponsePerUser(true);
    spec.items.forEach(function (it) { addItem(form, it); });

    var fresh = !spec.sheet_id;
    var ss = fresh
      ? SpreadsheetApp.create(spec.title + ' (Responses)')
      : SpreadsheetApp.openById(spec.sheet_id);
    if (fresh) made.push(ss.getId());
    var tab = linkSheet(form, ss, fresh);

    var editors = unique(req.editors || []);
    if (editors.length) {
      form.addEditors(editors);
      ss.addEditors(editors);
    }
    if (req.folder_id) {
      var folder = DriveApp.getFolderById(req.folder_id);
      made.forEach(function (id) { DriveApp.getFileById(id).moveTo(folder); });
    }

    var published = null;
    if (typeof form.isPublished === 'function') {
      if (!form.isPublished()) form.setPublished(true);
      published = form.isPublished();
    }

    return {
      ok: true,
      account: account(),
      form_id: form.getId(),
      edit_url: form.getEditUrl(),
      responder_url: form.getPublishedUrl(),
      published: published,
      sheet_id: ss.getId(),
      sheet_url: ss.getUrl(),
      sheet_tab: tab,
      editors: editors,
    };
  } catch (err) {
    made.forEach(function (id) {
      try { DriveApp.getFileById(id).setTrashed(true); } catch (_) {}
    });
    throw err;
  }
}

// Points the form's responses at ss and returns the name of the tab Forms adds for them.
// In a spreadsheet created for this form, the blank tab it started with is removed.
function linkSheet(form, ss, fresh) {
  var before = ss.getSheets().map(function (s) { return s.getSheetId(); });
  form.setDestination(FormApp.DestinationType.SPREADSHEET, ss.getId());
  SpreadsheetApp.flush();
  ss = SpreadsheetApp.openById(ss.getId());
  var added = ss.getSheets().filter(function (s) { return before.indexOf(s.getSheetId()) < 0; });
  if (added.length !== 1) throw new Error('could not find the response tab Forms added');
  if (fresh) {
    ss.getSheets().forEach(function (s) {
      if (s.getSheetId() !== added[0].getSheetId() && s.getLastRow() === 0) ss.deleteSheet(s);
    });
  }
  return added[0].getName();
}

function addItem(form, it) {
  var item;
  switch (it.type) {
    case 'text':
      item = form.addTextItem();
      if (it.validate) item.setValidation(textValidation(it.validate));
      break;
    case 'paragraph': item = form.addParagraphTextItem(); break;
    case 'choice':
      item = form.addMultipleChoiceItem().setChoiceValues(it.choices);
      if (it.other) item.showOtherOption(true);
      break;
    case 'checkbox':
      item = form.addCheckboxItem().setChoiceValues(it.choices);
      if (it.other) item.showOtherOption(true);
      break;
    case 'dropdown': item = form.addListItem().setChoiceValues(it.choices); break;
    case 'scale':
      item = form.addScaleItem().setBounds(
        it.low === undefined ? 1 : it.low,
        it.high === undefined ? 5 : it.high);
      if (it.low_label || it.high_label) item.setLabels(it.low_label || '', it.high_label || '');
      break;
    case 'date': item = form.addDateItem(); break;
    case 'time': item = form.addTimeItem(); break;
    case 'datetime': item = form.addDateTimeItem(); break;
    case 'grid': item = form.addGridItem().setRows(it.rows).setColumns(it.columns); break;
    case 'checkbox_grid':
      item = form.addCheckboxGridItem().setRows(it.rows).setColumns(it.columns);
      break;
    case 'section': item = form.addSectionHeaderItem(); break;
    case 'page': item = form.addPageBreakItem(); break;
  }
  item.setTitle(it.title);
  if (it.help) item.setHelpText(it.help);
  if (it.required && QUESTION_TYPES[it.type]) item.setRequired(true);
}

function textValidation(kind) {
  var b = FormApp.createTextValidation();
  if (kind === 'email') b.requireTextIsEmail();
  else if (kind === 'number') b.requireNumber();
  else if (kind === 'url') b.requireTextIsUrl();
  return b.build();
}

// Checks the whole spec before anything is created, so a bad spec leaves nothing behind.
function validate(spec) {
  if (!spec || typeof spec !== 'object') throw new Error('spec must be a JSON object');
  var errs = [];
  if (!spec.title) errs.push('title is required');
  if (!Array.isArray(spec.items) || !spec.items.length) errs.push('items must be a non-empty array');
  var titles = {};
  (spec.items || []).forEach(function (it, i) {
    var at = 'items[' + i + ']';
    if (!it || typeof it !== 'object') return errs.push(at + ': must be an object');
    if (!QUESTION_TYPES[it.type] && !LAYOUT_TYPES[it.type]) {
      return errs.push(at + ': unknown type "' + it.type + '"');
    }
    if (!it.title) errs.push(at + ': title is required');
    if (QUESTION_TYPES[it.type] && it.title) {
      // Response columns are named after question titles, so they must be unique.
      if (titles[it.title]) errs.push(at + ': duplicate question title "' + it.title + '"');
      titles[it.title] = true;
    }
    if (/^(choice|checkbox|dropdown)$/.test(it.type) && !nonEmpty(it.choices)) {
      errs.push(at + ': choices must be a non-empty array');
    }
    if (/grid$/.test(it.type) && !(nonEmpty(it.rows) && nonEmpty(it.columns))) {
      errs.push(at + ': rows and columns must be non-empty arrays');
    }
    if (it.type === 'scale') {
      var low = it.low === undefined ? 1 : it.low;
      var high = it.high === undefined ? 5 : it.high;
      if (low !== 0 && low !== 1) errs.push(at + ': low must be 0 or 1');
      if (!(high >= 3 && high <= 10 && high === Math.floor(high))) {
        errs.push(at + ': high must be a whole number from 3 to 10');
      }
    }
    if (it.validate !== undefined) {
      if (it.type !== 'text') errs.push(at + ': validate only applies to text questions');
      else if (!TEXT_VALIDATIONS[it.validate]) errs.push(at + ': validate must be email, number or url');
    }
    if (it.other && it.type !== 'choice' && it.type !== 'checkbox') {
      errs.push(at + ': other only applies to choice and checkbox questions');
    }
  });
  if (errs.length) throw new Error('invalid spec:\n' + errs.join('\n'));
}

function nonEmpty(a) {
  return Array.isArray(a) && a.length > 0;
}

function unique(a) {
  return a.filter(function (x, i) { return x && a.indexOf(x) === i; });
}
