// One language at a time: Malayalam by default, English with one tap (login screen or More → Language).
// Owner: Hiba. Short words on screen; longer explanations live behind the "?" buttons (info_* keys).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class L {
  static final lang = ValueNotifier<String>('ml');
  static bool get ml => lang.value == 'ml';

  static Future<void> load() async {
    lang.value = (await SharedPreferences.getInstance()).getString('lang') ?? 'ml';
  }

  static Future<void> set(String code) async {
    lang.value = code;
    (await SharedPreferences.getInstance()).setString('lang', code);
  }
}

/// Text for a key in the chosen language. `{n}`-style holders are filled from [args].
String tr(String key, [Map<String, Object?> args = const {}]) {
  final pair = _t[key];
  var s = pair == null ? key : (L.ml ? pair.$1 : pair.$2);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// A record's own name in the chosen language (name_ml / name_en, label_ml / label_en ...).
String pick(Map<String, dynamic>? r, String base) {
  if (r == null) return '';
  final first = L.ml ? r['${base}_ml'] : r['${base}_en'];
  final other = L.ml ? r['${base}_en'] : r['${base}_ml'];
  final s = '${first ?? ''}'.trim();
  return s.isNotEmpty ? s : '${other ?? r[base] ?? ''}';
}

const monthsMlFull = ['ജനുവരി', 'ഫെബ്രുവരി', 'മാർച്ച്', 'ഏപ്രിൽ', 'മേയ്', 'ജൂൺ', 'ജൂലൈ', 'ഓഗസ്റ്റ്', 'സെപ്റ്റംബർ', 'ഒക്ടോബർ', 'നവംബർ', 'ഡിസംബർ'];
const monthsEnFull = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthsEnShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthsMlShort = ['ജനു', 'ഫെബ്', 'മാർ', 'ഏപ്രി', 'മേയ്', 'ജൂൺ', 'ജൂലൈ', 'ഓഗ', 'സെപ്', 'ഒക്', 'നവം', 'ഡിസം'];

/// "October 2026" / "ഒക്ടോബർ 2026" for "2026-10".
String monthName(String month, {bool short = false}) {
  final i = int.parse(month.substring(5, 7)) - 1;
  final y = month.substring(0, 4);
  final names = L.ml ? (short ? monthsMlShort : monthsMlFull) : (short ? monthsEnShort : monthsEnFull);
  return short ? names[i] : '${names[i]} $y';
}

/// "17 Oct 2026" / "17 ഒക് 2026".
String dayName(String iso) {
  final i = int.parse(iso.substring(5, 7)) - 1;
  return '${int.parse(iso.substring(8, 10))} ${(L.ml ? monthsMlShort : monthsEnShort)[i]} ${iso.substring(0, 4)}';
}

const _t = <String, (String, String)>{
  // App
  'app_name': ('മിത്ര', 'Mitra'),
  'tagline': ('എന്റെ ബിസിനസ് ഡയറി', 'My business diary'),
  'hello': ('നമസ്കാരം', 'Hello'),
  'todays_business': ('ഇന്നത്തെ ബിസിനസ്', "Today's business"),
  'money_today': ('ഇന്ന് കിട്ടിയ പണം', 'Money received today'),
  'from_sales': ('{n} വിൽപ്പനയിൽ നിന്ന്', 'from {n} sales'),
  'no_sales_yet': ('ഇന്ന് ഇതുവരെ ഒന്നുമില്ല', 'Nothing yet today'),
  'this_month': ('ഈ മാസം', 'This month'),
  'other_rate': ('മറ്റ്', 'Other'),
  'this_month_profit': ('ഈ മാസത്തെ ലാഭം', "This month's profit"),
  'goal_left': ('ഇനി {amt}', '{amt} to go'),
  'ready_by': ('{when} ആകുമ്പോൾ', 'by {when}'),

  // Nav
  'nav_home': ('ഹോം', 'Home'),
  'nav_records': ('കണക്ക്', 'Records'),
  'nav_speak': ('പറയൂ', 'Speak'),
  'nav_products': ('സാധനങ്ങൾ', 'Products'),
  'nav_more': ('കൂടുതൽ', 'More'),

  // Home tiles
  'add_income': ('വരവ് ചേർക്കുക', 'Add income'),
  'add_income_sub': ('കിട്ടിയ പണം', 'Money I received'),
  'add_expense': ('ചെലവ് ചേർക്കുക', 'Add expense'),
  'add_expense_sub': ('ചെലവാക്കിയ പണം', 'Money I spent'),
  'my_products': ('എന്റെ സാധനങ്ങൾ', 'My products'),
  'my_products_sub': ('ഞാൻ വിൽക്കുന്നവ', 'Items I sell'),
  'my_profit': ('എന്റെ ലാഭം', 'My profit'),
  'my_profit_sub': ('ശരിക്കുള്ള ലാഭം', 'What I really earn'),

  // Add income / expense
  'what_sold': ('എന്താണ് വിറ്റത്?', 'What did you sell?'),
  'choose_or_speak': ('തിരഞ്ഞെടുക്കൂ, അല്ലെങ്കിൽ പറയൂ', 'Choose item or speak'),
  'how_many': ('എത്ര എണ്ണം?', 'How many?'),
  'total_amount': ('ആകെ തുക', 'Total amount'),
  'save': ('സേവ് ചെയ്യുക', 'Save'),
  'saved': ('സേവ് ചെയ്തു', 'Saved'),
  'removed': ('മാറ്റി', 'Removed'),
  'undo': ('തിരികെ', 'Undo'),
  'delete': ('മായ്ക്കുക', 'Delete'),
  'cancel': ('വേണ്ട', 'Cancel'),
  'or_speak': ('അല്ലെങ്കിൽ പറയൂ', 'Or speak instead'),
  'speak_income_eg': ('"ഇന്ന് 12 ബിരിയാണി വിറ്റു"', '"I sold 12 biriyani today"'),
  'what_spent': ('എന്തിനാണ് ചെലവാക്കിയത്?', 'What did you spend on?'),
  'amount': ('തുക', 'Amount'),
  'date': ('തീയതി', 'Date'),
  'gst_on_bill': ('ബില്ലിലെ ജിഎസ്ടി (ഉണ്ടെങ്കിൽ)', 'GST on the bill (if any)'),
  'more_details': ('കൂടുതൽ വിവരം', 'More details'),
  'what_item': ('എന്ത് സാധനം? (ഉദാ: അരി)', 'Which item? (e.g. rice)'),
  'speak_expense_eg': ('"200 രൂപയ്ക്ക് അരി വാങ്ങി"', '"Bought rice for 200 rupees"'),

  // Expense categories
  'cat_ingredients': ('ചേരുവകൾ', 'Ingredients'),
  'cat_packaging': ('പാക്കിംഗ്', 'Packaging'),
  'cat_gas': ('ഗ്യാസ്', 'Gas'),
  'cat_transport': ('യാത്ര', 'Transport'),
  'cat_electricity': ('കറന്റ്', 'Electricity'),
  'cat_rent': ('വാടക', 'Rent'),
  'cat_phone': ('ഫോൺ', 'Phone'),
  'cat_emi': ('ഇഎംഐ', 'EMI'),
  'cat_other': ('മറ്റുള്ളവ', 'Others'),

  // Records
  'records': ('എന്റെ കണക്ക്', 'My records'),
  'all': ('എല്ലാം', 'All'),
  'income': ('വരവ്', 'Income'),
  'expense': ('ചെലവ്', 'Expense'),
  'today': ('ഇന്ന്', 'Today'),
  'yesterday': ('ഇന്നലെ', 'Yesterday'),
  'by_call': ('ഫോൺ വിളിയിലൂടെ', 'By phone call'),
  'nothing_here': ('ഇവിടെ ഒന്നുമില്ല', 'Nothing here yet'),

  // Profit / report
  'total_income': ('ആകെ വരവ്', 'Total income'),
  'total_expense': ('ആകെ ചെലവ്', 'Total expenses'),
  'profit': ('ലാഭം', 'Profit'),
  'loss': ('നഷ്ടം', 'Loss'),
  'where_spent': ('പണം പോയ വഴി', 'Where I spent'),
  'mitra_noticed': ('മിത്ര ശ്രദ്ധിച്ചത്', 'Mitra noticed'),
  'monthly_report': ('മാസ റിപ്പോർട്ട്', 'Monthly report'),
  'week_n': ('ആഴ്ച {n}', 'Week {n}'),
  'best_sellers': ('കൂടുതൽ വിറ്റത്', 'Best sellers'),
  'last_6_months': ('കഴിഞ്ഞ 6 മാസം', 'Last 6 months'),
  'monthly_bills_short': ('മാസ ബില്ലുകൾ', 'Monthly bills'),
  'totals_only': ('ഈ മാസത്തിന്റെ ആകെ തുക മാത്രമേ ഉള്ളൂ', 'Only the totals are kept for this month'),
  'see_report': ('മാസ റിപ്പോർട്ട് കാണുക', 'See monthly report'),
  'share': ('പങ്കിടുക', 'Share'),

  // Products
  'add_product': ('പുതിയ സാധനം ചേർക്കുക', 'Add new product'),
  'edit_product': ('സാധനം മാറ്റുക', 'Edit product'),
  'name_ml': ('പേര് (മലയാളം)', 'Name (Malayalam)'),
  'name_en': ('പേര് (English)', 'Name (English)'),
  'price': ('വില (₹)', 'Price (₹)'),

  // Speak
  'speak_to_add': ('പറഞ്ഞ് ചേർക്കുക', 'Speak to add'),
  'tap_to_speak': ('സംസാരിക്കാൻ തൊടൂ', 'Tap to speak'),
  'listening': ('കേൾക്കുന്നു…', 'Listening…'),
  'speak_hint': ('മലയാളത്തിലോ ഇംഗ്ലീഷിലോ പറയാം', 'You can say it in Malayalam or English'),
  'examples': ('ഉദാഹരണങ്ങൾ', 'Examples'),
  'eg1': ('"ഇന്ന് 12 ബിരിയാണി വിറ്റു"', '"I sold 12 biriyani"'),
  'eg2': ('"30 ചപ്പാത്തി, 20 പൊറോട്ട"', '"30 chapathi and 20 parotta"'),
  'eg3': ('"200 രൂപയ്ക്ക് അരി വാങ്ങി"', '"Bought rice for 200"'),
  'eg4': ('"ഗ്യാസ് 900"', '"Gas refill 900"'),
  'is_this_right': ('ഇത് ശരിയാണോ?', 'Is this right?'),
  'didnt_catch': ('മനസ്സിലായില്ല. ഒന്നുകൂടി പറയൂ, അല്ലെങ്കിൽ തിരഞ്ഞെടുക്കൂ.', "Didn't catch that. Say it again, or choose below."),
  'type_instead': ('ടൈപ്പ് ചെയ്യാം', 'Type instead'),
  'no_mic': ('ഈ ഫോണിൽ സംസാരം കിട്ടുന്നില്ല. ടൈപ്പ് ചെയ്യൂ.', "Voice isn't available on this phone. Type instead."),
  'you_said': ('നിങ്ങൾ പറഞ്ഞത്', 'You said'),

  // More
  'more': ('കൂടുതൽ', 'More'),
  'business_details': ('എന്റെ ബിസിനസ്', 'My business details'),
  'business_details_sub': ('പേര്, സ്ഥലം, ഫോൺ', 'Name, place, phone'),
  'monthly_bills': ('മാസ ബില്ലുകൾ', 'Monthly bills'),
  'monthly_bills_sub': ('ഗ്യാസ്, വാടക, ഇഎംഐ', 'Gas, rent, EMIs'),
  'savings': ('സമ്പാദ്യ ലക്ഷ്യം', 'Savings goal'),
  'savings_sub': ('എപ്പോൾ എത്തും, ഇഎംഐ താങ്ങുമോ', 'When you get there, can you afford an EMI'),
  'gst': ('ജിഎസ്ടി, നികുതി', 'GST & tax'),
  'gst_sub': ('കാൽക്കുലേറ്റർ, രജിസ്ട്രേഷൻ', 'Calculator, registration'),
  'schemes': ('സർക്കാർ പദ്ധതികൾ', 'Government schemes'),
  'schemes_sub': ('പുതിയ അറിയിപ്പുകൾ', 'Latest updates'),
  'bulk': ('ഒരുമിച്ച് വാങ്ങാം', 'Buy together'),
  'bulk_sub': ('അടുത്തുള്ളവരോടൊപ്പം, കുറഞ്ഞ വിലയ്ക്ക്', 'With women nearby, at a lower price'),
  'call_me': ('മിത്ര എന്നെ വിളിക്കട്ടെ', 'Mitra, call me'),
  'call_me_sub': ('ഫോണിൽ പറഞ്ഞാൽ മതി', 'Just say it on the phone'),
  'calling': ('വിളിക്കുന്നു…', 'Calling…'),
  'call_started': ('ഫോൺ ഇപ്പോൾ അടിക്കും', 'Your phone will ring now'),
  'call_unavailable': ('ഫോൺ വിളി ഇപ്പോൾ ലഭ്യമല്ല', "The phone call isn't available right now"),
  'added_by_call': ('ഫോൺ വിളിയിലൂടെ ചേർത്തു', 'Added by phone call'),
  'support': ('സംസാരിക്കാൻ ഒരാൾ', 'Someone to talk to'),
  'support_sub': ('സൗജന്യം', 'Free'),
  'language': ('ഭാഷ', 'Language'),
  'help': ('സഹായം', 'Help'),
  'help_sub': ('എങ്ങനെ ഉപയോഗിക്കാം', 'How to use Mitra'),
  'reset_demo': ('ഡെമോ വീണ്ടും തുടങ്ങുക', 'Reset demo'),
  'reset_done': ('ഡെമോ പുതുക്കി', 'Demo reset'),
  'logout': ('പുറത്തിറങ്ങുക', 'Log out'),
  'live': ('ലൈവ്', 'Live'),
  'offline': ('ഓഫ്‌ലൈൻ', 'Offline'),

  // Login
  'welcome': ('സ്വാഗതം', 'Welcome'),
  'phone': ('ഫോൺ നമ്പർ', 'Phone number'),
  'pin': ('4 അക്ക രഹസ്യ നമ്പർ', '4-digit PIN'),
  'login': ('കയറുക', 'Log in'),
  'demo_login': ('ഡെമോ കാണുക', 'Try the demo'),
  'demo_login_sub': ('ഷീലയുടെ ബിസിനസ്, ഉദാഹരണ കണക്കുകളോടെ', "Sheela's business, with sample data"),
  'new_here': ('പുതിയ ആളാണോ? ചേരൂ', 'New here? Join'),
  'wrong_login': ('നമ്പറോ PIN-ഓ ശരിയല്ല', 'Phone number or PIN is wrong'),
  'demo_hint': ('ഡെമോ: 98765 43210 · PIN 1234', 'Demo: 98765 43210 · PIN 1234'),
  'or': ('അല്ലെങ്കിൽ', 'or'),

  // Bills
  'add_bill': ('ബിൽ ചേർക്കുക', 'Add bill'),
  'bill_type': ('ഏത് ബിൽ?', 'Which bill?'),
  'due_day': ('അടയ്ക്കേണ്ട ദിവസം', 'Due day of month'),
  'total': ('ആകെ', 'Total'),

  // Savings goal + EMI
  'saved_so_far': ('ഇതുവരെ', 'Saved so far'),
  'per_month': ('ഓരോ മാസവും {amt}', '{amt} every month'),
  'ready_in': ('{n} മാസം കൊണ്ട്', 'in {n} months'),
  'goal_reached': ('ലക്ഷ്യം എത്തി!', 'Goal reached!'),
  'add_saving': ('സമ്പാദ്യം ചേർക്കുക', 'Add to savings'),
  'emi_title': ('പുതിയ ഇഎംഐ താങ്ങുമോ?', 'Can I afford a new EMI?'),
  'emi_amount': ('മാസം അടയ്ക്കേണ്ട തുക', 'Monthly amount'),
  'emi_ok': ('താങ്ങാം', 'Looks affordable'),
  'emi_tight': ('ശ്രദ്ധിക്കണം', 'Tight, be careful'),
  'emi_risky': ('ബുദ്ധിമുട്ടാകും', 'Risky'),
  'after_usual': ('സാധാരണ മാസം ബാക്കി', 'Left in a usual month'),
  'after_worst': ('മോശം മാസം ബാക്കി', 'Left in your worst month'),
  'emi_share': ('ലാഭത്തിന്റെ {p}%', '{p}% of usual profit'),

  // GST
  'gst_calc': ('ജിഎസ്ടി കാൽക്കുലേറ്റർ', 'GST calculator'),
  'gst_add': ('വിലയിൽ ജിഎസ്ടി ചേർക്കുക', 'Add GST to a price'),
  'gst_remove': ('വിലയിലെ ജിഎസ്ടി കണ്ടെത്തുക', 'Find GST inside a price'),
  'gst_rate': ('ജിഎസ്ടി നിരക്ക്', 'GST rate'),
  'price_before': ('ജിഎസ്ടി ഇല്ലാത്ത വില', 'Price before GST'),
  'gst_amount': ('ജിഎസ്ടി', 'GST'),
  'price_after': ('ജിഎസ്ടി ഉൾപ്പെടെ', 'Price with GST'),
  'gst_paid_year': ('ഈ വർഷം നിങ്ങൾ അടച്ച ജിഎസ്ടി', 'GST you paid this year'),
  'gst_paid_note': ('വാങ്ങിയ സാധനങ്ങളുടെ ബില്ലുകളിൽ നിന്ന്', 'From the bills of what you bought'),
  'gst_reg': ('ജിഎസ്ടി രജിസ്ട്രേഷൻ വേണോ?', 'Do I need GST registration?'),
  'gst_not_needed': ('ഇപ്പോൾ വേണ്ട', 'Not yet'),
  'gst_needed': ('വേണ്ടിവരും', 'Yes, it may be needed'),
  'year_sales': ('ഈ വർഷത്തെ വിൽപ്പന', 'Sales this year'),
  'limit_unchecked': ('പരിധി ഔദ്യോഗിക സൈറ്റിൽ ഇനിയും ഉറപ്പാക്കിയിട്ടില്ല', 'The limit is not yet checked on the official site'),
  'checked_on': ('ഉറപ്പാക്കിയത്', 'Checked on'),
  'guidance': ('മാർഗ്ഗനിർദ്ദേശം മാത്രം. കുടുംബശ്രീ MEC-യോടോ ടാക്സ് കൺസൾട്ടന്റിനോടോ ഉറപ്പാക്കുക.',
      'Guidance only. Confirm with your Kudumbashree MEC or a tax consultant.'),

  // Schemes
  'open_schemes': ('ഇപ്പോൾ ചേരാവുന്ന പദ്ധതികൾ', 'Schemes you can join now'),
  'schemes_only': ('പദ്ധതി വാർത്തകൾ മാത്രം', 'Scheme news only'),
  'from_govt': ('സർക്കാരിൽ നിന്ന് പുതിയത്', 'New from the Government'),
  'pib_source': ('PIB · ഔദ്യോഗിക അറിയിപ്പ്', 'PIB · official press release'),
  'no_scheme_news': ('ഇന്ന് പദ്ധതി വാർത്തകൾ ഇല്ല', 'No scheme news today'),
  'show_all_news': ('എല്ലാ സർക്കാർ വാർത്തകളും കാണുക', 'Show all government news'),
  'checked_schemes': ('ഉറപ്പാക്കിയ പദ്ധതികൾ', 'Checked schemes'),
  'documents': ('വേണ്ട രേഖകൾ', 'Documents you need'),
  'being_checked': ('ഉറപ്പാക്കിക്കൊണ്ടിരിക്കുന്നു', 'Still being checked'),
  'offline_saved': ('ഇന്റർനെറ്റ് ഇല്ല. അവസാനം കിട്ടിയത്:', 'No internet. Last fetched:'),
  'cant_load': ('ഇപ്പോൾ ലോഡ് ആകുന്നില്ല', "Can't load right now"),
  'open': ('തുറക്കുക', 'Open'),

  // Bulk
  'women_together': ('{n} പേർ ഒരുമിച്ച്', '{n} women together'),
  'join_group': ('ഞാനും ചേരാം', 'Join'),
  'you_are_in': ('നിങ്ങളും ഉണ്ട്', "You're in"),
  'how_much_need': ('എത്ര വേണം?', 'How much do you need?'),

  // Support
  'support_line': ('ബിസിനസും വീടും ഒരുമിച്ച് നോക്കുന്നത് എളുപ്പമല്ല. സംസാരിക്കാൻ ഒരാളെ വേണമെങ്കിൽ വിളിക്കൂ.',
      'Running a business and a home is hard. If you want someone to talk to, call.'),

  // Business details
  'your_name': ('പേര്', 'Name'),
  'your_place': ('സ്ഥലം', 'Place'),

  // Help
  'how_income': ('വരവ് എങ്ങനെ ചേർക്കാം', 'How to add income'),
  'how_expense': ('ചെലവ് എങ്ങനെ ചേർക്കാം', 'How to add expense'),
  'how_profit': ('ലാഭം എങ്ങനെ കാണാം', 'How to see profit'),
  'how_speak': ('പറഞ്ഞ് എങ്ങനെ ചേർക്കാം', 'How to add by speaking'),
  'how_call': ('ഫോൺ വിളിയിലൂടെ', 'Using a phone call'),
  'how_income_a': ('ഹോമിൽ "വരവ് ചേർക്കുക" തൊടുക. സാധനം തിരഞ്ഞെടുക്കുക, + ഉപയോഗിച്ച് എണ്ണം ആക്കുക, സേവ് ചെയ്യുക.',
      'On Home, tap "Add income". Pick the item, use + to set how many, then Save.'),
  'how_expense_a': ('"ചെലവ് ചേർക്കുക" തൊടുക. എന്തിനാണെന്ന് തിരഞ്ഞെടുത്ത് തുക എഴുതി സേവ് ചെയ്യുക.',
      'Tap "Add expense". Choose what it was for, type the amount, then Save.'),
  'how_profit_a': ('"എന്റെ ലാഭം" തൊടുക. വരവിൽ നിന്ന് ചെലവും ബില്ലുകളും കുറച്ചതാണ് ലാഭം.',
      'Tap "My profit". Profit is income minus expenses and bills.'),
  'how_speak_a': ('താഴെ നടുവിലെ മൈക്ക് തൊടുക. "ഇന്ന് 12 ബിരിയാണി വിറ്റു" എന്ന് പറയുക. ശരിയാണെങ്കിൽ സേവ് ചെയ്യുക.',
      'Tap the mic in the middle at the bottom. Say "I sold 12 biriyani". If it is right, Save.'),
  'how_call_a': ('സാധാരണ ഫോണിൽ നിന്നും മിത്രയെ വിളിച്ച് വിൽപ്പന പറയാം. ആപ്പിൽ അത് തനിയെ വരും.',
      'From any basic phone, call Mitra and say what you sold. It shows up in the app by itself.'),

  // Info texts ("?" buttons)
  'info_home': ('ഇന്ന് കിട്ടിയ പണം വിൽപ്പനയിൽ നിന്നാണ്. താഴെയുള്ള ബട്ടണുകളിലൂടെ വരവും ചെലവും ചേർക്കാം.',
      "Money received today comes from today's sales. Use the buttons below to add income and expenses."),
  'info_profit': ('ലാഭം = വരവ് − (ചെലവ് + മാസ ബില്ലുകൾ). കണക്കുകൂട്ടൽ ഫോണിൽ തന്നെ, കൃത്യമായി.',
      'Profit = income − (expenses + monthly bills). Worked out exactly on the phone.'),
  'info_records': ('ഓരോ വരവും ചെലവും ദിവസം തിരിച്ച്. മായ്ക്കാൻ ഒന്ന് തൊടുക.', 'Every income and expense, day by day. Tap one to delete it.'),
  'info_products': ('നിങ്ങൾ വിൽക്കുന്നതും വിലയും. വില മാറ്റിയാൽ ഈ മാസത്തെ കണക്കും പുതിയ വിലയിൽ മാറും.',
      "What you sell and the price. Changing a price also changes this month's totals."),
  'info_report': ('ഓരോ ആഴ്ചയിലെ വരവും ചെലവും. മാസ ബില്ലുകൾ ആകെ ചെലവിൽ ഉണ്ട്.',
      'Income and expenses for each week. Monthly bills are included in total expenses.'),
  'info_gst': ('ജിഎസ്ടി കാൽക്കുലേറ്റർ കണക്ക് മാത്രം ചെയ്യുന്നു. നിരക്ക് നിങ്ങൾ തിരഞ്ഞെടുക്കുന്നു.',
      'The calculator only does the maths. You choose the rate.'),
  'info_schemes': ('സർക്കാരിന്റെ ഔദ്യോഗിക അറിയിപ്പുകൾ (PIB) നേരിട്ട്. വായ്പകൾ കാണിക്കില്ല. അപേക്ഷിക്കും മുമ്പ് ഔദ്യോഗിക സൈറ്റിൽ ഉറപ്പാക്കുക.',
      'Straight from official Government press releases (PIB). Loans are never shown. Check the official site before applying.'),
  'info_bulk': ('അടുത്തുള്ള സ്ത്രീകൾ ഒരുമിച്ച് ഓർഡർ ചെയ്താൽ മൊത്തവിലയ്ക്ക് സാധനം കിട്ടും.',
      'When women nearby order together, they get wholesale prices.'),
  'info_savings': ('ഓരോ മാസവും മാറ്റിവെക്കുന്ന തുകയനുസരിച്ച് ലക്ഷ്യം എപ്പോൾ എത്തും എന്ന് കാണാം. മിത്ര ഒരിക്കലും വായ്പ നിർദ്ദേശിക്കില്ല.',
      'See when you reach your goal from what you put aside each month. Mitra never suggests loans.'),
};
