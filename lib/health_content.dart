// lib/config/health_content.dart

class HealthTip {
  final String category;
  final Map<String, String> title; // en, hi, or
  final Map<String, String> body;  // en, hi, or

  const HealthTip({
    required this.category,
    required this.title,
    required this.body,
  });
}

// --- MASTER LIBRARY (CONVERSION FOCUSED) ---
const List<HealthTip> healthTipsPart1 = [
  // ==========================================
  // 1. THE MEDICINE TRAP (CREATE DOUBT ABOUT PILLS)
  // ==========================================
  HealthTip(
    category: "Awareness",
    title: {'en': "The Medicine Trap", 'hi': "दवाइयों का चक्रव्यूह", 'or': "ଔଷଧର ଚକ୍ରବ୍ୟୂହ"},
    body: {'en': "BP meds cause acidity. Acidity meds block Iron. Low Iron causes hair fall. You treat one symptom and get three new diseases. MNT is the only way to break this cycle.", 'hi': "बीपी की गोली से एसिडिटी होती है, एसिडिटी की गोली से खून की कमी। आप एक बीमारी दबाते हैं, तीन नई पाल लेते हैं। MNT ही इसका एकमात्र हल है।", 'or': "ରକ୍ତଚାପ ଔଷଧରୁ ଅମ୍ଳତା ହୁଏ, ଅମ୍ଳତା ଔଷଧରୁ ରକ୍ତହୀନତା | ଗୋଟିଏ ରୋଗ ଭଲ କରିବାକୁ ଯାଇ ଆପଣ ତିନୋଟି ନୂଆ ରୋଗ ଆଣୁଛନ୍ତି |"},
  ),
  HealthTip(
    category: "Awareness",
    title: {'en': "Symptom vs Cure", 'hi': "इलाज या धोखा?", 'or': "ଚିକିତ୍ସା ନା ଧୋକା?"},
    body: {'en': "Diabetes pills don't fix the pancreas; they just force-flush sugar out. The organ keeps dying silently. Don't just manage numbers; revive the organ with MNT.", 'hi': "शुगर की दवा बीमारी ठीक नहीं करती, बस शुगर लेवल छुपाती है। अंदर ही अंदर शरीर खोखला हो रहा है। सही पोषण (MNT) ही अंग को बचा सकता है।", 'or': "ମଧୁମେହ ଔଷଧ କେବଳ ସୁଗାର୍ କମାଏ, କିନ୍ତୁ ଶରୀର ଭିତରୁ ନଷ୍ଟ ହେଉଥାଏ | MNT ଦ୍ୱାରା ଅଙ୍ଗକୁ ବଞ୍ଚାନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Awareness",
    title: {'en': "Cost of Ignorance", 'hi': "लापरवाही की कीमत", 'or': "ଅବହେଳାର ମୂଲ୍ୟ"},
    body: {'en': "A customized diet plan costs pennies compared to a single day in the ICU. You will pay for your health eventually—either to a Dietitian now or a Surgeon later.", 'hi': "डाइट प्लान का खर्च ICU के एक दिन के खर्च से भी कम है। या तो आज डाइटिशियन को चुनें या कल सर्जन को। चुनाव आपका है।", 'or': "ଆଜି ଡାଏଟିସିଆନ୍ ଙ୍କ ପରାମର୍ଶ ନିଅନ୍ତୁ, ନଚେତ୍ କାଲି ଡାକ୍ତରଖାନାରେ ଲକ୍ଷ ଲକ୍ଷ ଖର୍ଚ୍ଚ କରିବାକୁ ପଡିବ |"},
  ),
  HealthTip(
    category: "Awareness",
    title: {'en': "Painkiller Warning", 'hi': "किडनी का दुश्मन", 'or': "କିଡନୀର ଶତ୍ରୁ"},
    body: {'en': "Taking painkillers for headaches or joints? You are slowly eroding your kidneys. Dialysis is painful and expensive. Anti-inflammatory MNT is the safe alternative.", 'hi': "रोज दर्द की गोली खाना अपनी किडनी को मारने जैसा है। डायलिसिस के दर्द से बचना है तो आज ही सही डाइट अपनाएं।", 'or': "ପ୍ରତିଦିନ ପେନ୍ କିଲର୍ ଖାଇଲେ କିଡନୀ ନଷ୍ଟ ହୁଏ | ଡାଏଲିସିସ୍ ରୁ ବଞ୍ଚିବା ପାଇଁ MNT ଆପଣାନ୍ତୁ |"},
  ),

  // ==========================================
  // 2. DIABETES (FEAR OF COMPLICATIONS)
  // ==========================================
  HealthTip(
    category: "Diabetes",
    title: {'en': "Amputation Risk", 'hi': "पैर कटने का डर", 'or': "ପାଦ କାଟିବା ଭୟ"},
    body: {'en': "Tingling in feet isn't tiredness; it's nerve death. Ignore this, and gangrene follows. Medicine can't fix nerves; only glucose control via MNT can.", 'hi': "पैरों में झनझनाहट थकान नहीं, नसें मरने का संकेत है। अगर ध्यान नहीं दिया तो पैर काटने की नौबत आ सकती है।", 'or': "ପାଦ ଝିମ୍ ଝିମ୍ ହେବା ସ୍ନାୟୁ ମରିବାର ଲକ୍ଷଣ | ସାବଧାନ ନହେଲେ ପାଦ କାଟିବାକୁ ପଡିପାରେ |"},
  ),
  HealthTip(
    category: "Diabetes",
    title: {'en': "Blindness & Sugar", 'hi': "अंधेपन का खतरा", 'or': "ଅନ୍ଧ ହେବାର ଭୟ"},
    body: {'en': "High sugar dissolves the tiny blood vessels in your eyes (Retinopathy). You won't feel pain until your vision goes dark. Stabilize sugar naturally before it's too late.", 'hi': "हाई शुगर आपकी आंखों की रोशनी छीन सकता है। अंधापन आने से पहले अपनी डाइट सुधारें।", 'or': "ଅଧିକ ସୁଗାର୍ ଆଖି ନଷ୍ଟ କରିଦିଏ | ଅନ୍ଧ ହେବା ପୂର୍ବରୁ ସାବଧାନ ହୁଅନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Diabetes",
    title: {'en': "Kidney Failure", 'hi': "किडनी फेलियर", 'or': "କିଡନୀ ଫେଲ୍"},
    body: {'en': "Diabetes is the #1 cause of kidney failure. Your creatinine is rising silently. Pills stress the kidneys further. MNT reduces the load on kidneys.", 'hi': "शुगर की वजह से किडनी सबसे जल्दी खराब होती है। गोलियां किडनी पर और लोड डालती हैं। सही डाइट ही बचाव है।", 'or': "ମଧୁମେହ କିଡନୀ ଖରାପ ହେବାର ମୁଖ୍ୟ କାରଣ | ଔଷଧ କିଡନୀ ଉପରେ ଚାପ ପକାଏ |"},
  ),
  HealthTip(
    category: "Diabetes",
    title: {'en': "Silent Heart Attack", 'hi': "साइलेंट हार्ट अटैक", 'or': "ନୀରବ ହୃଦଘାତ"},
    body: {'en': "Diabetics often don't feel chest pain during a heart attack due to nerve damage. You could drop dead without warning. Reversing diabetes is a survival necessity.", 'hi': "शुगर के मरीजों को हार्ट अटैक का दर्द महसूस नहीं होता। यह जानलेवा हो सकता है। इसे जड़ से ठीक करना जरूरी है।", 'or': "ମଧୁମେହ ରୋଗୀଙ୍କୁ ହାର୍ଟ ଆଟାକ୍ ର ଯନ୍ତ୍ରଣା ଜଣାପଡେ ନାହିଁ | ସାବଧାନ |"},
  ),
  HealthTip(
    category: "Diabetes",
    title: {'en': "The Roti Trap", 'hi': "रोटी से शुगर?", 'or': "ରୁଟିରୁ ସୁଗାର୍?"},
    body: {'en': "Switching from Rice to Wheat didn't help, did it? Both spike insulin dangerously. You need a calculated grain structure, not just a switch.", 'hi': "चावल छोड़कर रोटी खाने से शुगर कम नहीं होगी। दोनों खतरनाक हैं। सही अनाज कौन सा है, यह जानना जरूरी है।", 'or': "ଭାତ ବଦଳରେ ରୁଟି ଖାଇଲେ ଲାଭ ନାହିଁ | ଉଭୟ ବିପଦଜନକ |"},
  ),

  // ==========================================
  // 3. HEART & BP (STROKE RISK)
  // ==========================================
  HealthTip(
    category: "Heart Health",
    title: {'en': "Stroke Warning", 'hi': "लकवे का खतरा", 'or': "ପକ୍ଷାଘାତ ଭୟ"},
    body: {'en': "High BP bursts blood vessels in the brain causing paralysis. Meds artificially lower pressure but don't clean arteries. MNT cleans the blockage.", 'hi': "हाई बीपी से दिमाग की नस फट सकती है (लकवा)। दवा सिर्फ बीपी कम करती है, ब्लॉकेज नहीं हटाती।", 'or': "ଉଚ୍ଚ ରକ୍ତଚାପ ଯୋଗୁଁ ବ୍ରେନ୍ ଷ୍ଟ୍ରୋକ ହୋଇପାରେ | ଔଷଧ କେବଳ ଚାପ କମାଏ, ବ୍ଲକେଜ୍ ସଫା କରେନି |"},
  ),
  HealthTip(
    category: "Heart Health",
    title: {'en': "Erectile Dysfunction", 'hi': "पुरुषों में कमजोरी", 'or': "ପୁରୁଷତ୍ୱ ହାନି"},
    body: {'en': "Poor blood flow affects ALL organs. ED is often the first sign of a coming heart attack. Viagra won't fix your arteries; Heart-Healthy MNT will.", 'hi': "कमजोरी दिल की बीमारी का पहला संकेत हो सकता है। यह नसों के ब्लॉक होने का सबूत है।", 'or': "ଶାରୀରିକ ଦୁର୍ବଳତା ହୃଦଘାତର ପୂର୍ବ ଲକ୍ଷଣ ହୋଇପାରେ |"},
  ),
  HealthTip(
    category: "Heart Health",
    title: {'en': "Cholesterol Meds", 'hi': "कोलेस्ट्रॉल की दवा", 'or': "କୋଲେଷ୍ଟ୍ରୋଲ୍ ଔଷଧ"},
    body: {'en': "Statins lower cholesterol but increase diabetes risk by 40%. Why trade one disease for another? Fix your lipid profile naturally with food.", 'hi': "कोलेस्ट्रॉल की दवा से शुगर होने का खतरा बढ़ जाता है। एक बीमारी हटाकर दूसरी क्यों लाएं?", 'or': "କୋଲେଷ୍ଟ୍ରୋଲ୍ ଔଷଧ ଖାଇଲେ ଡାଇବେଟିସ୍ ହେବାର ଭୟ ଥାଏ |"},
  ),
  HealthTip(
    category: "Heart Health",
    title: {'en': "Salt isn't the Only Enemy", 'hi': "नमक ही नहीं", 'or': "କେବଳ ଲୁଣ ନୁହେଁ"},
    body: {'en': "Cutting salt isn't enough if your arteries are stiff from insulin. Sugar hurts your heart more than salt. A specialized diet plan is needed.", 'hi': "सिर्फ नमक कम करने से बीपी ठीक नहीं होगा। चीनी और मैदा दिल के लिए ज्यादा खतरनाक हैं।", 'or': "କେବଳ ଲୁଣ କମାଇଲେ ହେବନି, ଚିନି ହୃଦୟ ପାଇଁ ଅଧିକ ଖରାପ |"},
  ),

  // ==========================================
  // 4. WOMEN'S HEALTH (INFERTILITY & CANCER RISK)
  // ==========================================
  HealthTip(
    category: "Women",
    title: {'en': "PCOS & Infertility", 'hi': "बांझपन का खतरा", 'or': "ବନ୍ଧ୍ୟା ଦୋଷ"},
    body: {'en': "PCOS is the leading cause of infertility. Pills force a period but kill egg quality. If you want to conceive naturally, you must fix metabolism first.", 'hi': "PCOS बांझपन का मुख्य कारण है। गोलियां केवल पीरियड लाती हैं, मां बनने की क्षमता नहीं बढ़ातीं।", 'or': "PCOS ବନ୍ଧ୍ୟା ଦୋଷର ମୁଖ୍ୟ କାରଣ | ଔଷଧ କେବଳ ପିରିୟଡ୍ କରାଏ, ଗର୍ଭଧାରଣ କ୍ଷମତା ବଢ଼ାଏ ନାହିଁ |"},
  ),
  HealthTip(
    category: "Women",
    title: {'en': "Fibroids & Surgery", 'hi': "गर्भाशय का ऑपरेशन", 'or': "ଅପରେସନ୍ ଭୟ"},
    body: {'en': "Doctors suggest removing the uterus for fibroids. But fibroids grow back if Estrogen Dominance isn't fixed. Save your organs with MNT.", 'hi': "ऑपरेशन के बाद भी गांठें दोबारा हो सकती हैं अगर खान-पान नहीं सुधरा। अपने अंग को बचाएं।", 'or': "ଅପରେସନ୍ ପରେ ମଧ୍ୟ ଗାଣ୍ଠି ହୋଇପାରେ | ଖାଦ୍ୟ ନିୟନ୍ତ୍ରଣ କରି ନିଜକୁ ବଞ୍ଚାନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Women",
    title: {'en': "Thyroid & Depression", 'hi': "थायराइड और डिप्रेशन", 'or': "ଥାଇରଏଡ୍ ଏବଂ ଚିନ୍ତା"},
    body: {'en': "Thyroid pills correct TSH reports but not your mood or energy. Are you still tired and sad despite meds? Your cells are starving. Fix absorption.", 'hi': "रिपोर्ट नार्मल है फिर भी थकान और उदासी है? इसका मतलब दवा काम नहीं कर रही। पोषण की जरूरत है।", 'or': "ରିପୋର୍ଟ ଠିକ ଥିଲେ ମଧ୍ୟ ଯଦି ଦୁର୍ବଳ ଲାଗୁଛି, ତେବେ ଔଷଧ କାମ କରୁନାହିଁ |"},
  ),
  HealthTip(
    category: "Women",
    title: {'en': "Early Menopause", 'hi': "समय से पहले बुढ़ापा", 'or': "ସମୟ ପୂର୍ବରୁ ବାର୍ଦ୍ଧକ୍ୟ"},
    body: {'en': "Poor nutrition forces early menopause, causing rapid aging and brittle bones. Don't let your body age faster than your age. Hormone balance is key.", 'hi': "गलत खान-पान से समय से पहले मेनोपॉज आता है, जिससे हड्डियां कमजोर और चेहरे पर झुर्रियां आती हैं।", 'or': "ଖରାପ ଖାଦ୍ୟ ଯୋଗୁଁ ଅଳ୍ପ ବୟସରେ ବାର୍ଦ୍ଧକ୍ୟ ଆସେ |"},
  ),

  // ==========================================
  // 5. ORGANS & LIVER (IRREVERSIBLE DAMAGE)
  // ==========================================
  HealthTip(
    category: "Liver",
    title: {'en': "Fatty Liver to Cirrhosis", 'hi': "लिवर खराब होना", 'or': "ଲିଭର ଖରାପ ହେବା"},
    body: {'en': "Fatty liver has NO symptoms until it turns into Cirrhosis (Permanent Damage). Don't wait for pain. Reversing it NOW is your only chance.", 'hi': "फैटी लिवर का कोई दर्द नहीं होता जब तक वह पूरी तरह खराब न हो जाए। अभी नहीं सुधरे तो कभी नहीं।", 'or': "ଲିଭର ଖରାପ ହେବା ଯାଏଁ ଜଣାପଡେ ନାହିଁ | ଏବେ ସତର୍କ ହୁଅନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Liver",
    title: {'en': "Detox Tea Scam", 'hi': "डिटॉक्स का झूठ", 'or': "ଡିଟକ୍ସ ମିଛ"},
    body: {'en': "Green tea and 'Detox' powders cannot clean a liver clogged with visceral fat. Only a medically calculated fat-loss diet works.", 'hi': "ग्रीन टी पीने से लिवर साफ नहीं होगा। इसके लिए मेडिकल डाइट की जरूरत है। विज्ञापनों के जाल में न फंसें।", 'or': "ଗ୍ରୀନ୍ ଟି ପିଇଲେ ଲିଭର ସଫା ହୁଏନି | ସଠିକ୍ ଚିକିତ୍ସା ଦରକାର |"},
  ),
  HealthTip(
    category: "Gut",
    title: {'en': "Gas Leads to Ulcers", 'hi': "गैस से अल्सर", 'or': "ଗ୍ୟାସ୍ ରୁ ଅଲସର୍"},
    body: {'en': "Ignoring daily gas? It burns the stomach lining causing Ulcers and even Cancer. Antacids ruin digestion further. Fix the root cause immediately.", 'hi': "रोज गैस की गोली खाने से पेट में अल्सर हो सकता है। यह कैंसर का रूप भी ले सकता है।", 'or': "ପ୍ରତିଦିନ ଗ୍ୟାସ୍ ବଟିକା ଖାଇଲେ ପେଟରେ ଘା ହୋଇପାରେ |"},
  ),

  // ==========================================
  // 6. WEIGHT & LIFESTYLE (FAD DIET DANGERS)
  // ==========================================
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Keto/GM Diet Danger", 'hi': "क्रैश डाइट का खतरा", 'or': "କ୍ରାସ୍ ଡାଏଟ୍ ବିପଦ"},
    body: {'en': "Rapid weight loss destroys your metabolism and causes hair fall. You will gain back DOUBLE the weight. Do it scientifically or don't do it.", 'hi': "जल्दी वजन घटाने के चक्कर में बाल झड़ जाएंगे और वजन दोगुना वापस आएगा। शरीर के साथ खिलवाड़ न करें।", 'or': "ଜଲଦି ଓଜନ କମାଇଲେ କେଶ ଝଡିବ ଏବଂ ଓଜନ ଦୁଇଗୁଣା ବଢିବ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Visceral Fat Kills", 'hi': "पेट की चर्बी", 'or': "ପେଟ ଚର୍ବି"},
    body: {'en': "Belly fat isn't just cosmetic; it's metabolically active tissue poisoning your organs 24/7. It's a ticking time bomb for Heart Attack.", 'hi': "पेट की चर्बी सिर्फ मोटापा नहीं, यह हार्ट अटैक का टाइम बम है। इसे तुरंत कम करना जरूरी है।", 'or': "ପେଟ ଚର୍ବି ହୃଦଘାତର ମୁଖ୍ୟ କାରଣ | ଏହାକୁ ଅଣଦେଖା କରନ୍ତୁ ନାହିଁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Stunted Growth", 'hi': "बच्चों का विकास", 'or': "ପିଲାଙ୍କ ବିକାଶ"},
    body: {'en': "Giving health drinks (Horlicks/Bournvita) full of sugar? You are stunting their growth and immunity. Real nutrition comes from food, not boxes.", 'hi': "बाजार के हेल्थ ड्रिंक्स में केवल चीनी है। इससे बच्चों की लंबाई और दिमाग रुक जाता है। असली पोषण दें।", 'or': "ବାଜାରର ହେଲ୍ଥ ଡ୍ରିଙ୍କ୍ସରେ କେବଳ ଚିନି ଥାଏ | ଏହା ପିଲାଙ୍କ ବିକାଶ ରୋକିଦିଏ |"},
  ),

  // ==========================================
  // 7. GENERAL (THE SOLUTION GAP)
  // ==========================================
  HealthTip(
    category: "General",
    title: {'en': "Why You Fail", 'hi': "आप क्यों हारते हैं?", 'or': "ଆପଣ କାହିଁକି ହାରୁଛନ୍ତି?"},
    body: {'en': "YouTube tips are general. Your body is unique. What works for others might harm you. You need a personalized clinical roadmap, not random advice.", 'hi': "इंटरनेट के नुस्खे सबके लिए नहीं होते। आपका शरीर अलग है। आपको एक विशेषज्ञ की जरूरत है जो आपकी रिपोर्ट के अनुसार डाइट बनाए।", 'or': "ଇଣ୍ଟରନେଟ୍ ଦେଖି ଚିକିତ୍ସା କରନ୍ତୁ ନାହିଁ | ଆପଣଙ୍କୁ ବିଶେଷଜ୍ଞଙ୍କ ପରାମର୍ଶ ଦରକାର |"},
  ),
  HealthTip(
    category: "General",
    title: {'en': "Don't Self Medicate", 'hi': "खुद डॉक्टर न बनें", 'or': "ନିଜେ ଡାକ୍ତର ହୁଅନ୍ତୁ ନାହିଁ"},
    body: {'en': "Trying to fix hormones with home remedies? You might mess them up further. Hormones are complex. Trust clinical science, not kitchen experiments.", 'hi': "घरेलू नुस्खों से हार्मोन ठीक नहीं होते, बल्कि और बिगड़ सकते हैं। अपने शरीर पर प्रयोग न करें।", 'or': "ଘରୋଇ ଉପଚାରରେ ହରମୋନ୍ ଠିକ ହୁଏନି | ନିଜ ଶରୀର ସହ ଖେଳନ୍ତୁ ନାହିଁ |"},
  ),
  HealthTip(
    category: "General",
    title: {'en': "Prevention is Cheaper", 'hi': "बचाव ही सस्ता है", 'or': "ସୁରକ୍ଷା ଶସ୍ତା ଅଟେ"},
    body: {'en': "Dialysis costs ₹20k/month. Knee replacement ₹4 Lakhs. MNT prevents these disasters. Invest in prevention before disease bankrupts you.", 'hi': "इलाज कराने से बेहतर है बीमारी को आने ही न दें। अस्पताल का खर्चा घर बेच सकता है। सही समय पर सही सलाह लें।", 'or': "ରୋଗ ହେବା ପରେ ଖର୍ଚ୍ଚ କରିବା ଅପେକ୍ଷା ରୋଗ ନ ହେବା ଭଲ |"},
  ),
];
// --- PART 2: TIPS 51 TO 100 (CONVERSION FOCUSED) ---
const List<HealthTip> healthTipsPart2 = [
  // ==========================================
  // 5. WEIGHT LOSS (THE METABOLIC DAMAGE)
  // ==========================================
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Starvation Destroys You", 'hi': "भूखा रहने का अंजाम", 'or': "ଉପବାସର ପରିଣାମ"},
    body: {'en': "Skipping meals doesn't burn fat; it eats your muscles. Your metabolism crashes, and you gain back double the weight. Only a calculated clinical diet works.", 'hi': "खाना छोड़ने से चर्बी नहीं, ताकत घटती है। इससे शरीर और फूल जाता है। सही डाइट प्लान ही इसका उपाय है।", 'or': "ଖାଦ୍ୟ ଛାଡିଲେ ଚର୍ବି କମେନି, ବରଂ ଶରୀର ଦୁର୍ବଳ ହୁଏ ଏବଂ ଓଜନ ଦୁଇଗୁଣା ବଢ଼େ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "The 'Thin-Fat' Indian", 'hi': "पतले होकर भी बीमार?", 'or': "ପତଳା କିନ୍ତୁ ଅସୁସ୍ଥ?"},
    body: {'en': "You look thin but have a belly? That is Visceral Fat wrapping your liver and heart. This is more dangerous than being overweight. It causes silent heart attacks.", 'hi': "अगर आप पतले हैं लेकिन पेट बाहर है, तो यह खतरे की घंटी है। यह अंदरूनी अंगों को सड़ा रहा है।", 'or': "ଯଦି ଆପଣ ପତଳା କିନ୍ତୁ ପେଟ ବାହାରିଛି, ତେବେ ହୃଦଘାତର ଭୟ ଅଛି |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Gym vs. Kitchen", 'hi': "जिम या डाइट?", 'or': "ଜିମ୍ ନା ଡାଏଟ୍?"},
    body: {'en': "You cannot out-run a bad diet. 1 hour of gym burns 300 calories; one samosa adds 300 back. Weight loss happens 80% in the kitchen, not the gym.", 'hi': "जिम में मेहनत बेकार है अगर खाना सही नहीं है। वजन रसोइ में घटता है, जिम में नहीं।", 'or': "ଜିମ୍ ରେ ପରିଶ୍ରମ ବୃଥା ଯଦି ଖାଦ୍ୟ ଠିକ ନାହିଁ | ଓଜନ ରୋଷେଇ ଘରେ କମେ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Fat Burners Warning", 'hi': "फैट बर्नर दवाएं", 'or': "ଫ୍ୟାଟ୍ ବର୍ନର୍ ଔଷଧ"},
    body: {'en': "Pills that promise weight loss often contain banned substances that damage the heart and kidneys. Don't risk organ failure for a smaller waist.", 'hi': "वजन घटाने वाली गोलियां किडनी और लिवर खराब करती हैं। अपनी जान जोखिम में न डालें।", 'or': "ଓଜନ କମାଇବା ବଟିକା କିଡନୀ ଏବଂ ଲିଭର ନଷ୍ଟ କରେ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Post-Pregnancy", 'hi': "डिलीवरी के बाद वजन", 'or': "ପ୍ରସବ ପରର ଓଜନ"},
    body: {'en': "Trying to lose weight too fast after delivery weakens your bones for life. You need a specialized lactation diet to lose fat while feeding the baby.", 'hi': "जल्दबाजी में वजन घटाना हड्डियों को कमजोर कर देगा। स्तनपान के साथ सही डाइट जरूरी है।", 'or': "ତରତର ହୋଇ ଓଜନ କମାନ୍ତୁ ନାହିଁ, ହାଡ ଦୁର୍ବଳ ହୋଇଯିବ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Keto Diet Risk", 'hi': "कीटो डाइट का सच", 'or': "କିଟୋ ଡାଏଟ୍ ସତ୍ୟ"},
    body: {'en': "Keto gives fast results but can cause severe hair fall, thyroid crash, and gallstones. Sustainable weight loss needs balance, not extremes.", 'hi': "कीटो डाइट से बाल झड़ते हैं और पथरी हो सकती है। शरीर को संतुलित आहार चाहिए।", 'or': "କିଟୋ ଡାଏଟ୍ ରେ କେଶ ଝଡେ ଏବଂ ପଥର ହୁଏ | ସନ୍ତୁଳିତ ଖାଦ୍ୟ ଖାଆନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Walking Isn't Enough", 'hi': "सिर्फ टहलना काफी नहीं", 'or': "କେବଳ ଚାଲିବା ଯଥେଷ୍ଟ ନୁହେଁ"},
    body: {'en': "Walking is great for the heart, but it won't fix insulin resistance or hormonal belly fat. You need a metabolic reset diet for that.", 'hi': "सिर्फ टहलने से पेट की चर्बी नहीं जाएगी। इसके लिए हार्मोन बैलेंस करना जरूरी है।", 'or': "କେବଳ ଚାଲିଲେ ପେଟ ଚର୍ବି କମିବ ନାହିଁ | ହରମୋନ୍ ଠିକ କରିବା ଦରକାର |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Dinner Timing", 'hi': "रात का खाना", 'or': "ରାତ୍ରି ଭୋଜନ"},
    body: {'en': "Late dinners go straight to fat storage. Your body shuts down digestion at night. Eat with the sun to stay lean.", 'hi': "देर रात खाने से शरीर फैट जमा करता है। सूरज ढलने के साथ खाना कम करें।", 'or': "ଡେରି ରାତିରେ ଖାଇଲେ ଚର୍ବି ବଢ଼େ | ସୂର୍ଯ୍ୟାସ୍ତ ପରେ କମ୍ ଖାଆନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Snacking Habit", 'hi': "बिस्कुट-नमकीन", 'or': "ବିସ୍କୁଟ୍-ମିକ୍ସଚର୍"},
    body: {'en': "Your 'light' tea-time biscuits are made of Maida and Palm Oil. They clog arteries and spike insulin daily. Stop feeding disease to your body.", 'hi': "चाय के साथ बिस्कुट-नमकीन खाना बीमारी को न्यौता है। ये मैदा और खराब तेल से बनते हैं।", 'or': "ଚା ସହ ବିସ୍କୁଟ୍ ଖାଇବା ବିପଦଜନକ | ଏଥିରେ ମଇଦା ଏବଂ ଖରାପ ତେଲ ଥାଏ |"},
  ),
  HealthTip(
    category: "Weight Loss",
    title: {'en': "Willpower vs Hormones", 'hi': "इच्छाशक्ति या हार्मोन?", 'or': "ଇଚ୍ଛାଶକ୍ତି ନା ହରମୋନ୍?"},
    body: {'en': "You aren't lazy; your hormones are broken. High insulin makes you hungry. You can't fight biology with willpower. Fix the biology with MNT.", 'hi': "मोटापा आलस नहीं, बीमारी है। हार्मोन बिगड़ने से भूख ज्यादा लगती है। इसे डाइट से ठीक करें।", 'or': "ମୋଟାପଣ ଆଳସ୍ୟ ନୁହେଁ, ରୋଗ | ହରମୋନ୍ ଠିକ କରନ୍ତୁ |"},
  ),

  // ==========================================
  // 6. GUT HEALTH (THE ACIDITY PILL TRAP)
  // ==========================================
  HealthTip(
    category: "Gut Health",
    title: {'en': "Antacid Side Effects", 'hi': "गैस की गोली के नुकसान", 'or': "ଗ୍ୟାସ୍ ବଟିକାର କ୍ଷତି"},
    body: {'en': "Taking gas pills daily? They stop calcium and B12 absorption. Years of antacids lead to weak bones and nerve damage. Heal the gut instead.", 'hi': "रोज गैस की गोली खाने से हड्डियां कमजोर होती हैं। यह समस्या को दबाती है, ठीक नहीं करती।", 'or': "ପ୍ରତିଦିନ ଗ୍ୟାସ୍ ବଟିକା ଖାଇଲେ ହାଡ ଦୁର୍ବଳ ହୁଏ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "Bloating is Rotting", 'hi': "पेट फूलना", 'or': "ପେଟ ଫୁଲିବା"},
    body: {'en': "Constant bloating means food is fermenting (rotting) inside you, releasing toxins into your blood. This causes brain fog and fatigue.", 'hi': "पेट फूलने का मतलब है खाना अंदर सड़ रहा है। इससे खून में जहर फैलता है।", 'or': "ପେଟ ଫୁଲିବା ମାନେ ଖାଦ୍ୟ ଭିତରେ ପଚୁଛି | ଏହା ରକ୍ତକୁ ବିଷାକ୍ତ କରେ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "Constipation & Cancer", 'hi': "कब्ज और कैंसर", 'or': "କୋଷ୍ଠକାଠିନ୍ୟ ଏବଂ କ୍ୟାନସର"},
    body: {'en': "Chronic constipation keeps toxins in the colon. Long-term, this increases colon cancer risk. Laxatives kill gut nerves. Use fiber-rich MNT.", 'hi': "कब्ज को हल्का न समझें। पेट साफ न होने से आंतों का कैंसर हो सकता है। चूर्ण नहीं, खाना बदलें।", 'or': "କୋଷ୍ଠକାଠିନ୍ୟ କ୍ୟାନସର କରାଇପାରେ | ଚୂର୍ଣ୍ଣ ନୁହେଁ, ଖାଦ୍ୟ ବଦଳାନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "Leaky Gut", 'hi': "आंतों में छेद", 'or': "ଅନ୍ତନଳୀ ଘା"},
    body: {'en': "Gluten and painkillers tear your gut lining. Toxins leak into blood, causing autoimmune diseases like Thyroid and Arthritis.", 'hi': "मैदा और पेनकिलर आंतों को फाड़ देते हैं। इससे थायराइड और गठिया जैसी बीमारियां होती हैं।", 'or': "ମଇଦା ଏବଂ ପେନ୍ କିଲର୍ ଅନ୍ତନଳୀ ଖରାପ କରେ, ଯାହା ଥାଇରଏଡ୍ କରାଏ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "Piles & Fissures", 'hi': "बवासीर (Piles)", 'or': "ମଳକଣ୍ଟକ (Piles)"},
    body: {'en': "Surgery removes piles, but they come back if digestion isn't fixed. You must soften stool naturally through diet, not just medicines.", 'hi': "ऑपरेशन के बाद भी बवासीर दोबारा हो सकती है अगर कब्ज ठीक न हो। जड़ से इलाज करें।", 'or': "ଅପରେସନ୍ ପରେ ମଧ୍ୟ ପାଇଲ୍ସ ହୋଇପାରେ ଯଦି ପେଟ ସଫା ନ ରୁହେ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "Tea on Empty Stomach", 'hi': "खाली पेट चाय", 'or': "ଖାଲି ପେଟରେ ଚା"},
    body: {'en': "Starting your day with tea burns the stomach lining and causes acidity all day. It's an addiction destroying your digestion.", 'hi': "सुबह की चाय पेट में तेजाब बनाती है। यह आपकी पाचन शक्ति को खत्म कर रही है।", 'or': "ସକାଳ ଚା ପେଟରେ ଏସିଡ୍ କରେ ଏବଂ ହଜମ ଶକ୍ତି ନଷ୍ଟ କରେ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "IBS Confusion", 'hi': "IBS की समस्या", 'or': "IBS ସମସ୍ୟା"},
    body: {'en': "Doctors say IBS has no cure? That's because it's a food sensitivity issue, not a disease. MNT identifies triggers and heals the gut.", 'hi': "IBS कोई बीमारी नहीं, खराब खान-पान का नतीजा है। सही डाइट से इसे कंट्रोल किया जा सकता है।", 'or': "IBS ଖରାପ ଖାଦ୍ୟ ପେୟ ଯୋଗୁଁ ହୁଏ | ସଠିକ୍ ଡାଏଟ୍ ଦ୍ୱାରା ଏହା ଠିକ ହୁଏ |"},
  ),
  HealthTip(
    category: "Gut Health",
    title: {'en': "Water & Digestion", 'hi': "पानी कब पिएं?", 'or': "ପାଣି କେତେବେଳେ ପିଇବେ?"},
    body: {'en': "Drinking water with meals dilutes stomach acid, leading to gas. Sip water 30 mins before or after. Small habits prevent big diseases.", 'hi': "खाने के साथ पानी पीने से जहर बनता है। 30 मिनट का नियम अपनाएं।", 'or': "ଖାଇବା ସହ ପାଣି ପିଇଲେ ବିଷ ହୁଏ | ୩୦ ମିନିଟ୍ ବ୍ୟବଧାନ ରଖନ୍ତୁ |"},
  ),

  // ==========================================
  // 7. LIVER (THE SILENT SUFFERER)
  // ==========================================
  HealthTip(
    category: "Liver",
    title: {'en': "Fatty Liver Ignorance", 'hi': "फैटी लिवर की अनदेखी", 'or': "ଫ୍ୟାଟି ଲିଭର ଅବହେଳା"},
    body: {'en': "Doctors say 'Grade 1 is normal'. It is NOT. It is the first step towards Diabetes and Cirrhosis. Reverse it before it scars permanently.", 'hi': "फैटी लिवर को सामान्य न समझें। यह आगे चलकर लिवर फेलियर और डायबिटीज बनता है।", 'or': "ଫ୍ୟାଟି ଲିଭରକୁ ସାଧାରଣ ଭାବନ୍ତୁ ନାହିଁ | ଏହା ଭବିଷ୍ୟତରେ ଲିଭର ଫେଲ୍ କରାଇପାରେ |"},
  ),
  HealthTip(
    category: "Liver",
    title: {'en': "Sugar > Alcohol", 'hi': "चीनी शराब से बुरी", 'or': "ଚିନି ମଦ ଠାରୁ ଖରାପ"},
    body: {'en': "You don't drink but have Fatty Liver? Fructose (Sugar) damages the liver exactly like Alcohol. Fruit juices and sweets are the culprit.", 'hi': "शराब न पीने वालों का लिवर चीनी खराब करती है। जूस और मिठाई लिवर के लिए जहर हैं।", 'or': "ମଦ ନ ପିଇଲେ ମଧ୍ୟ ଚିନି ଲିଭର ଖରାପ କରେ | ଜୁସ୍ ଏବଂ ମିଠା ବିଷ ସମାନ |"},
  ),
  HealthTip(
    category: "Liver",
    title: {'en': "Gallstones & Oil", 'hi': "पित्त की पथरी", 'or': "ପିତ୍ତ ପଥର"},
    body: {'en': "Avoiding oil completely causes gallstones because bile stops flowing. You need Good Fats (Ghee) to keep the gallbladder working.", 'hi': "तेल-घी बिल्कुल बंद करने से पित्त की थैली में पथरी होती है। अच्छा फैट खाना जरूरी है।", 'or': "ତେଲ ଘିଅ ବନ୍ଦ କଲେ ପିତ୍ତ ପଥର ହୁଏ | ଭଲ ଘିଅ ଖାଆନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Liver",
    title: {'en': "Detox Scam", 'hi': "डिटॉक्स का सच", 'or': "ଡିଟକ୍ସ ସତ୍ୟ"},
    body: {'en': "No pill or powder can detox the liver. Only the liver detoxes itself when you stop feeding it toxins. You need a Clinical Liver Reset Diet.", 'hi': "बाजार के पाउडर से लिवर साफ नहीं होता। सही खाना ही लिवर को ठीक कर सकता है।", 'or': "ବଜାର ପାଉଡର ଲିଭର ସଫା କରେନି | ସଠିକ୍ ଖାଦ୍ୟ ଲିଭର ଠିକ କରେ |"},
  ),
  HealthTip(
    category: "Liver",
    title: {'en': "Skin Signs", 'hi': "त्वचा और लिवर", 'or': "ଚର୍ମ ଏବଂ ଲିଭର"},
    body: {'en': "Itchy skin, acne, or pigmentation often means your liver is overloaded with toxins. Creams won't fix internal toxicity.", 'hi': "चेहरे पर दाग और खुजली लिवर खराब होने के संकेत हैं। क्रीम नहीं, डाइट बदलें।", 'or': "ମୁହଁରେ ଦାଗ ଏବଂ କୁଣ୍ଡାଇ ହେବା ଲିଭର ଖରାପର ଲକ୍ଷଣ |"},
  ),

  // ==========================================
  // 8. KIDNEY (THE DRUG VICTIM)
  // ==========================================
  HealthTip(
    category: "Kidney",
    title: {'en': "Creatinine Warning", 'hi': "क्रिएटिनिन का खतरा", 'or': "କ୍ରିଏଟିନିନ୍ ବିପଦ"},
    body: {'en': "If Creatinine is slightly high, 50% kidney function is already gone. Dialysis is the only next step unless you act NOW with a renal diet.", 'hi': "क्रिएटिनिन बढ़ना मतलब किडनी 50% खराब हो चुकी है। डायलिसिस से बचना है तो अभी संभलें।", 'or': "କ୍ରିଏଟିନିନ୍ ବଢିବା ମାନେ କିଡନୀ ୫୦% ଖରାପ | ଡାଏଲିସିସ୍ ରୁ ବଞ୍ଚିବା ପାଇଁ ସତର୍କ ହୁଅନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kidney",
    title: {'en': "Protein & Kidney", 'hi': "प्रोटीन और किडनी", 'or': "ପ୍ରୋଟିନ୍ ଏବଂ କିଡନୀ"},
    body: {'en': "Doctors say stop protein? Only if you have CKD. For others, protein is vital. Don't starve your body based on half-knowledge.", 'hi': "स्वस्थ इंसान के लिए प्रोटीन जरूरी है। अधूरी जानकारी से शरीर कमजोर न करें।", 'or': "ସୁସ୍ଥ ମଣିଷ ପାଇଁ ପ୍ରୋଟିନ୍ ଜରୁରୀ | ଅଧା ଜ୍ଞାନ ବିପଦଜନକ |"},
  ),
  HealthTip(
    category: "Kidney",
    title: {'en': "Foamy Urine", 'hi': "पेशाब में झाग", 'or': "ଫେଣଯୁକ୍ତ ପରିସ୍ରା"},
    body: {'en': "Foam in urine means protein is leaking because your kidney filters are damaged. This is the first red flag of failure.", 'hi': "पेशाब में झाग आना किडनी खराब होने की पहली निशानी है। तुरंत जांच कराएं।", 'or': "ପରିସ୍ରାରେ ଫେଣ ହେବା କିଡନୀ ଖରାପର ପ୍ରଥମ ଲକ୍ଷଣ |"},
  ),
  HealthTip(
    category: "Kidney",
    title: {'en': "Water & Stones", 'hi': "पथरी और पानी", 'or': "ପଥର ଏବଂ ପାଣି"},
    body: {'en': "Kidney stones are just concentrated urine minerals. Meds break stones, but diet prevents them from forming again.", 'hi': "दवा से पथरी टूटती है, लेकिन बार-बार बनती है। इसे रोकने के लिए डाइट बदलनी होगी।", 'or': "ଔଷଧରେ ପଥର ଭାଙ୍ଗେ, କିନ୍ତୁ ବାରମ୍ବାର ହୁଏ | ଖାଦ୍ୟ ବଦଳାନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kidney",
    title: {'en': "BP kills Kidneys", 'hi': "बीपी और किडनी", 'or': "ରକ୍ତଚାପ ଏବଂ କିଡନୀ"},
    body: {'en': "Uncontrolled BP hammers the delicate filters of your kidneys. Managing BP isn't just for the heart; it's to save your kidneys.", 'hi': "हाई बीपी किडनी को धीरे-धीरे खत्म कर देता है। बीपी कंट्रोल करना मजबूरी है।", 'or': "ଉଚ୍ଚ ରକ୍ତଚାପ କିଡନୀକୁ ଧୀରେ ଧୀରେ ନଷ୍ଟ କରେ |"},
  ),

  // ==========================================
  // 9. BODY PAIN & BONES (NUTRIENT DEFICIENCY)
  // ==========================================
  HealthTip(
    category: "Body Pain",
    title: {'en': "Vitamin D Crisis", 'hi': "हड्डियों का दर्द", 'or': "ହାଡ ବିନ୍ଧା"},
    body: {'en': "Back pain and depression are linked to low Vitamin D. 80% Indians are deficient. Pills work, but sun + diet works better.", 'hi': "कमर दर्द और थकान विटामिन डी की कमी है। सिर्फ गोली नहीं, धूप और सही खाना चाहिए।", 'or': "କମର ବିନ୍ଧା ଭିଟାମିନ୍ ଡି ଅଭାବରୁ ହୁଏ | ଖରା ପୁହାନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Body Pain",
    title: {'en': "Uric Acid Myth", 'hi': "यूरिक एसिड का सच", 'or': "ୟୁରିକ୍ ଏସିଡ୍ ସତ୍ୟ"},
    body: {'en': "Stop blaming Dal and Spinach. Sugar and Alcohol prevent kidneys from filtering uric acid. Cut sugar to fix gout.", 'hi': "दाल बंद न करें, चीनी और शराब बंद करें। इनसे यूरिक एसिड बढ़ता है, दाल से नहीं।", 'or': "ଡାଲି ବନ୍ଦ କରନ୍ତୁ ନାହିଁ, ଚିନି ଏବଂ ମଦ ବନ୍ଦ କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Body Pain",
    title: {'en': "Knee Pain Reality", 'hi': "घुटनों का दर्द", 'or': "ଆଣ୍ଠୁ ବିନ୍ଧା"},
    body: {'en': "Knee replacement is ₹4 Lakhs. Losing 10kg weight is free. Weight loss reduces knee pressure by 40kg. Choose wisely.", 'hi': "घुटने का ऑपरेशन महंगा है, वजन घटाना सस्ता है। वजन कम करें, दर्द गायब हो जाएगा।", 'or': "ଆଣ୍ଠୁ ଅପରେସନ୍ ମହଙ୍ଗା, ଓଜନ କମାଇବା ଶସ୍ତା | ନିଷ୍ପତ୍ତି ଆପଣଙ୍କର |"},
  ),
  HealthTip(
    category: "Body Pain",
    title: {'en': "B12 & Nerves", 'hi': "नसें और B12", 'or': "ସ୍ନାୟୁ ଏବଂ B12"},
    body: {'en': "Tingling hands/feet? Vegetarians often lack Vitamin B12. Nerve damage can become permanent if ignored.", 'hi': "हाथ सुन्न होना B12 की कमी है। इसे नजरअंदाज करने से नसें हमेशा के लिए खराब हो सकती हैं।", 'or': "ହାତ ଝିମ୍ ଝିମ୍ ହେବା B12 ଅଭାବ | ଅଣଦେଖା କଲେ ସ୍ନାୟୁ ନଷ୍ଟ ହେବ |"},
  ),
  HealthTip(
    category: "Body Pain",
    title: {'en': "Calcium Pills Risk", 'hi': "कैल्शियम की गोली", 'or': "କ୍ୟାଲସିୟମ୍ ବଟିକା"},
    body: {'en': "Calcium pills without Vitamin K2 deposit in arteries (heart block) instead of bones. Never self-medicate supplements.", 'hi': "बिना जानकारी कैल्शियम खाने से दिल की नसों में ब्लॉकेज हो सकती है। डॉक्टर से पूछें।", 'or': "ନ ଜାଣି କ୍ୟାଲସିୟମ୍ ଖାଇଲେ ହୃଦଘାତ ହୋଇପାରେ |"},
  ),
];
// --- PART 3: TIPS 101 TO 150 (CONVERSION FOCUSED) ---
const List<HealthTip> healthTipsPart3 = [
  // ==========================================
  // 10. CHILD NUTRITION (THE FUTURE AT RISK)
  // ==========================================
  HealthTip(
    category: "Kids",
    title: {'en': "The Health Drink Lie", 'hi': "हेल्थ ड्रिंक का सच", 'or': "ହେଲ୍ଥ ଡ୍ରିଙ୍କ୍ ସତ୍ୟ"},
    body: {'en': "Most 'Growth Drinks' are 40% sugar. You are feeding your child diabetes, not height. Real growth comes from Protein (Eggs/Paneer), not sugar powders.", 'hi': "बाजार के हेल्थ ड्रिंक्स में केवल चीनी है। इससे बच्चों की लंबाई नहीं, शुगर बढ़ती है। असली पोषण खाने से मिलता है।", 'or': "ବାଜାର ହେଲ୍ଥ ଡ୍ରିଙ୍କ୍ସରେ କେବଳ ଚିନି ଥାଏ | ଏହା ପିଲାଙ୍କୁ ରୋଗୀ କରୁଛି |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Picky Eaters", 'hi': "बच्चा खाना नहीं खाता?", 'or': "ପିଲା ଖାଉନାହାନ୍ତି?"},
    body: {'en': "Loss of appetite in kids is often Zinc deficiency, not a tantrum. Force-feeding won't help; fixing the deficiency will. Consult for a child diet plan.", 'hi': "बच्चे का खाना न खाना नखरा नहीं, जिंक की कमी हो सकती है। उसे डांटें नहीं, उसका इलाज करें।", 'or': "ପିଲା ନ ଖାଇବା ଜିଙ୍କ୍ ଅଭାବରୁ ହୋଇପାରେ | ତାଙ୍କୁ ଗାଳି ଦିଅନ୍ତୁ ନାହିଁ, ଚିକିତ୍ସା କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Childhood Obesity", 'hi': "मोटापा और बच्चे", 'or': "ପିଲାଙ୍କ ମୋଟାପଣ"},
    body: {'en': "Fat cells formed in childhood stay forever. An obese child becomes a diabetic adult. Don't call it 'Baby Fat'; fix it before it ruins their future.", 'hi': "बचपन का मोटापा जीवन भर की बीमारी बन जाता है। इसे 'प्यारा' न समझें, यह खतरनाक है।", 'or': "ପିଲାଦିନର ମୋଟାପଣ ଭବିଷ୍ୟତରେ ଡାଇବେଟିସ୍ କରାଏ | ଏହାକୁ ଅଣଦେଖା କରନ୍ତୁ ନାହିଁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Screen Time & Brain", 'hi': "मोबाइल और दिमाग", 'or': "ମୋବାଇଲ୍ ଏବଂ ମସ୍ତିଷ୍କ"},
    body: {'en': "Blue light destroys Melatonin (sleep hormone). Kids who sleep less grow less (Growth Hormone is released during sleep). No screens after 8 PM.", 'hi': "मोबाइल की रोशनी बच्चों की नींद और विकास रोक देती है। लंबाई बढ़ानी है तो फोन दूर रखें।", 'or': "ମୋବାଇଲ୍ ପିଲାଙ୍କ ନିଦ ଏବଂ ଉଚ୍ଚତା କମାଇଦିଏ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Sugar & Aggression", 'hi': "बच्चों का गुस्सा", 'or': "ପିଲାଙ୍କ ରାଗ"},
    body: {'en': "Sugar crash causes mood swings and hyperactivity. If your child is angry or can't focus, cut the sugar/chocolates first.", 'hi': "ज्यादा मीठा खाने वाले बच्चे जिद्दी और गुस्सैल होते हैं। व्यवहार सुधारना है तो चीनी कम करें।", 'or': "ଅଧିକ ମିଠା ଖାଇଲେ ପିଲା ଜିଦ୍ଦି ହୁଅନ୍ତି | ଚିନି ବନ୍ଦ କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Worms", 'hi': "पेट में कीड़े", 'or': "ପେଟରେ କୃମି"},
    body: {'en': "White patches on face? Grinding teeth at night? These are signs of worms eating your child's nutrition. De-worming is necessary.", 'hi': "चेहरे पर सफेद दाग कीड़ों का लक्षण है। ये बच्चे का सारा पोषण खा जाते हैं।", 'or': "ମୁହଁରେ ଧଳା ଦାଗ କୃମିର ଲକ୍ଷଣ | ଔଷଧ ଦିଅନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Breakfast is Brain", 'hi': "नाश्ता और पढ़ाई", 'or': "ଜଳଖିଆ ଏବଂ ପାଠ"},
    body: {'en': "Sending kids to school on just milk/biscuits? Their brain will starve by 10 AM. Give solid protein (Egg/Paratha) for better grades.", 'hi': "बिस्कुट खाकर स्कूल जाने वाले बच्चे पढ़ाई में कमजोर होते हैं। ठोस नाश्ता जरूरी है।", 'or': "ଖାଲି ବିସ୍କୁଟ୍ ଖାଇ ସ୍କୁଲ୍ ଗଲେ ପାଠ ମନେ ରୁହେନି |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Junk Food Addiction", 'hi': "चिप्स की लत", 'or': "ଚିପ୍ସ ନିଶା"},
    body: {'en': "Packaged chips contain MSG causing addiction like drugs. It destroys gut bacteria. Replace with Roasted Makhana or Peanuts.", 'hi': "पैकेट वाले चिप्स नशा बन जाते हैं। यह आंतों को सड़ा देते हैं। घर का खाना दें।", 'or': "ପ୍ୟାକେଟ୍ ଚିପ୍ସ ପେଟ ଖରାପ କରେ | ଘରୋଇ ଖାଦ୍ୟ ଦିଅନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Constipation", 'hi': "बच्चों में कब्ज", 'or': "ପିଲାଙ୍କ କୋଷ୍ଠକାଠିନ୍ୟ"},
    body: {'en': "Too much milk causes constipation in toddlers. Milk has no fiber. Add fruits and veggies to clear their stomach.", 'hi': "ज्यादा दूध पीने से बच्चों का पेट साफ नहीं होता। फल और सब्जी खिलाएं।", 'or': "ଅଧିକ କ୍ଷୀର ପିଇଲେ ପେଟ କଷା ହୁଏ | ଫଳ ଖୁଆନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Kids",
    title: {'en': "Height Stunting", 'hi': "लंबाई रुकना", 'or': "ଉଚ୍ଚତା ଅଟକିବା"},
    body: {'en': "Height is 60% genetics, 40% nutrition. If you miss the growth window (puberty), no medicine can help later. Act now.", 'hi': "अगर अभी सही खाना नहीं मिला, तो बच्चे की लंबाई हमेशा के लिए कम रह जाएगी।", 'or': "ଏବେ ସଠିକ୍ ଖାଦ୍ୟ ନ ଦେଲେ ପିଲାଙ୍କ ଉଚ୍ଚତା ବଢିବ ନାହିଁ |"},
  ),

  // ==========================================
  // 11. GENERAL LIFESTYLE (HABITS THAT KILL)
  // ==========================================
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Sitting Disease", 'hi': "बैठना खतरनाक है", 'or': "ବସିରହିବା ବିପଦ"},
    body: {'en': "Sitting for 8 hours is worse than smoking. It shuts down lipase (fat-burning enzyme). Walk 2 mins every hour or face heart risks.", 'hi': "लगातार बैठना धूम्रपान जितना खतरनाक है। हर घंटे 2 मिनट टहलें, वरना दिल की बीमारी तय है।", 'or': "ଲଗାତାର ବସିବା ଧୂମପାନ ପରି କ୍ଷତିକାରକ | ପ୍ରତି ଘଣ୍ଟାରେ ଚାଲନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Plastic Toxicity", 'hi': "प्लास्टिक का जहर", 'or': "ପ୍ଲାଷ୍ଟିକ ବିଷ"},
    body: {'en': "Drinking from plastic bottles? You are drinking microplastics that disrupt hormones (PCOS/Thyroid). Switch to Steel or Copper.", 'hi': "प्लास्टिक की बोतल से पानी पीना हार्मोन खराब करता है। स्टील या तांबे का बर्तन अपनाएं।", 'or': "ପ୍ଲାଷ୍ଟିକ ବୋତଲ ହରମୋନ୍ ଖରାପ କରେ | ଷ୍ଟିଲ୍ ବ୍ୟବହାର କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Aluminum Cookware", 'hi': "एल्युमीनियम बर्तन", 'or': "ଆଲୁମିନିୟମ୍ ବାସନ"},
    body: {'en': "Aluminum leaches into food, causing memory loss and kidney stress. Throw it out. Use Iron (Kadhai) or Steel.", 'hi': "एल्युमीनियम के बर्तन दिमाग और किडनी के लिए जहर हैं। लोहे या स्टील में खाना बनाएं।", 'or': "ଆଲୁମିନିୟମ୍ ବାସନ କିଡନୀ ପାଇଁ ଖରାପ | ଲୁହା କড়াই ବ୍ୟବହାର କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Refined Oil", 'hi': "रिफाइंड तेल", 'or': "ରିଫାଇଣ୍ଡ ତେଲ"},
    body: {'en': "Refined oils (Sunflower/Soybean) are chemically bleached. They cause inflammation in arteries. Go back to Mustard or Peanut oil.", 'hi': "रिफाइंड तेल नसों में सूजन लाता है। कच्ची घानी सरसों या मूंगफली का तेल खाएं।", 'or': "ରିଫାଇଣ୍ଡ ତେଲ ଶରୀର ପାଇଁ ବିଷ | ଘଣା ତେଲ ବ୍ୟବହାର କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Microwave Risk", 'hi': "प्लास्टिक और ओवन", 'or': "ମାଇକ୍ରୋୱେଭ୍"},
    body: {'en': "Heating food in plastic containers releases cancer-causing toxins directly into your meal. Always use glass.", 'hi': "माइक्रोवेव में प्लास्टिक के बर्तन गर्म करना कैंसर को न्यौता है। कांच का बर्तन इस्तेमाल करें।", 'or': "ପ୍ଲାଷ୍ଟିକ ବାସନରେ ଖାଦ୍ୟ ଗରମ କଲେ କ୍ୟାନସର ହୋଇପାରେ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Sleep & Hunger", 'hi': "नींद और भूख", 'or': "ନିଦ ଏବଂ ଭୋକ"},
    body: {'en': "Sleep deprivation makes you hungry. If you sleep 5 hours, you will overeat 500 calories the next day. Sleep is the best diet.", 'hi': "कम सोने से भूख बढ़ती है और वजन बढ़ता है। वजन घटाना है तो 7 घंटे सोएं।", 'or': "କମ୍ ଶୋଇଲେ ଅଧିକ ଭୋକ ଲାଗେ ଏବଂ ଓଜନ ବଢ଼େ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Sunlight & Depression", 'hi': "धूप और मूड", 'or': "ଖରା ଏବଂ ମନ"},
    body: {'en': "Feeling sad/low? It's likely Vitamin D deficiency. Morning sun boosts Serotonin (Happy Hormone). Don't just pop pills, take a sunbath.", 'hi': "उदासी और थकान धूप न मिलने का कारण है। सुबह की धूप लें, मूड ठीक हो जाएगा।", 'or': "ମନ ଦୁଃଖ ଲାଗିଲେ ଖରା ପୁହାନ୍ତୁ, ଭଲ ଲାଗିବ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Water Timing", 'hi': "पानी कब पिएं", 'or': "ପାଣି କେତେବେଳେ ପିଇବେ"},
    body: {'en': "Drinking water immediately after meals dilutes digestion enzymes, causing gas. Wait 30 mins. Small habits, big results.", 'hi': "खाने के तुरंत बाद पानी पीने से गैस बनती है। 30 मिनट रुककर पिएं।", 'or': "ଖାଇବା ପରେ ସଙ୍ଗେ ସଙ୍ଗେ ପାଣି ପିଇଲେ ଗ୍ୟାସ୍ ହୁଏ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Stress Cortisol", 'hi': "तनाव और पेट", 'or': "ଚିନ୍ତା ଏବଂ ପେଟ"},
    body: {'en': "You eat healthy but still have a belly? That's Cortisol (Stress). Stress stores fat specifically in the abdomen. Meditation is your medicine.", 'hi': "तनाव से पेट की चर्बी बढ़ती है, चाहे आप कितना भी कम खाएं। शांत रहना सीखें।", 'or': "ଚିନ୍ତା କଲେ ପେଟ ଚର୍ବି ବଢ଼େ | ଧ୍ୟାନ କରନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Lifestyle",
    title: {'en': "Walking Barefoot", 'hi': "नंगे पैर चलना", 'or': "ଖାଲି ପାଦରେ ଚାଲିବା"},
    body: {'en': "Walking on grass (Earthing) reduces body inflammation and lowers BP. It's a free therapy most people ignore.", 'hi': "घास पर नंगे पैर चलने से बीपी और तनाव कम होता है। इसे अपनी दिनचर्या बनाएं।", 'or': "ଘାସ ଉପରେ ଖାଲି ପାଦରେ ଚାଲିଲେ ରକ୍ତଚାପ କମେ |"},
  ),

  // ==========================================
  // 12. MYTHS (BUSTING GOOGLE KNOWLEDGE)
  // ==========================================
  HealthTip(
    category: "Myths",
    title: {'en': "Brown Sugar Myth", 'hi': "ब्राउन शुगर", 'or': "ବ୍ରାଉନ୍ ସୁଗାର୍"},
    body: {'en': "Brown sugar and Jaggery are 95% sugar. They spike insulin just like white sugar. Don't be fooled by the color.", 'hi': "गुड़ और ब्राउन शुगर भी चीनी ही हैं। शुगर के मरीज इनसे बचें, ये सुरक्षित नहीं हैं।", 'or': "ଗୁଡ ଏବଂ ବ୍ରାଉନ୍ ସୁଗାର୍ ମଧ୍ୟ ଚିନି ପରି କ୍ଷତିକାରକ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Green Tea", 'hi': "ग्रीन टी", 'or': "ଗ୍ରୀନ୍ ଟି"},
    body: {'en': "Green tea boosts metabolism by only 2%. It won't erase the damage of a bad diet. You can't sip your way to thinness.", 'hi': "सिर्फ ग्रीन टी पीने से वजन नहीं घटेगा। खाना सही करना होगा।", 'or': "କେବଳ ଗ୍ରୀନ୍ ଟି ପିଇଲେ ଓଜନ କମିବ ନାହିଁ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Desi Ghee", 'hi': "घी और दिल", 'or': "ଘିଅ ଏବଂ ହୃଦୟ"},
    body: {'en': "Ghee does NOT cause heart attacks; refined oil does. Ghee increases Good Cholesterol (HDL). Don't fear tradition.", 'hi': "देसी घी दिल के लिए अच्छा है। रिफाइंड तेल से ब्लॉकेज होती है।", 'or': "ଦେଶୀ ଘିଅ ହୃଦୟ ପାଇଁ ଭଲ | ରିଫାଇଣ୍ଡ ତେଲ ଖରାପ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Egg Yolks", 'hi': "अंडे का पीला भाग", 'or': "ଅଣ୍ଡା କେଶର"},
    body: {'en': "You throw away the yolk? You throw away Vitamin A, D, E, and K. The yolk doesn't clog arteries; sugar does.", 'hi': "अंडे का पीला भाग फायदेमंद है। इसे फेंकें नहीं, पूरा अंडा खाएं।", 'or': "ଅଣ୍ଡା କେଶରରେ ସବୁ ଭିଟାମିନ୍ ଥାଏ | ଏହାକୁ ଫିଙ୍ଗନ୍ତୁ ନାହିଁ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Sweat = Fat Loss", 'hi': "पसीना और वजन", 'or': "ଝାଳ ଏବଂ ଓଜନ"},
    body: {'en': "Sweating in a sauna is water loss, not fat loss. You can burn fat without sweating (e.g., Swimming). Don't obsess over sweat.", 'hi': "पसीना निकलने का मतलब फैट जलना नहीं है। यह सिर्फ पानी है जो वापस आ जाएगा।", 'or': "ଝାଳ ବାହାରିଲେ ଚର୍ବି କମେ ନାହିଁ, କେବଳ ପାଣି କମେ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Spot Reduction", 'hi': "सिर्फ पेट कम करना", 'or': "କେବଳ ପେଟ କମାଇବା"},
    body: {'en': "Doing 100 crunches won't remove belly fat. You lose fat from the whole body, not just one spot. Focus on diet, not just abs.", 'hi': "सिर्फ पेट की कसरत करने से पेट अंदर नहीं जाएगा। पूरे शरीर का वजन घटाना होगा।", 'or': "କେବଳ ପେଟ କମାଇବା ସମ୍ଭବ ନୁହେଁ | ପୂରା ଶରୀର ଓଜନ କମାଇବାକୁ ପଡିବ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Multigrain Bread", 'hi': "ब्राउन ब्रेड", 'or': "ବ୍ରାଉନ୍ ବ୍ରେଡ୍"},
    body: {'en': "Most 'Brown Bread' is just White Bread with caramel color. It raises blood sugar instantly. Read the label; look for 'Maida'.", 'hi': "बाजार की ब्राउन ब्रेड में अक्सर रंग मिला होता है। यह भी मैदा ही है।", 'or': "ବ୍ରାଉନ୍ ବ୍ରେଡ୍ ରେ ଅଧିକାଂଶ ମଇଦା ଏବଂ ରଙ୍ଗ ଥାଏ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Fruits at Night", 'hi': "रात में फल", 'or': "ରାତିରେ ଫଳ"},
    body: {'en': "Fruits contain fructose. Eating them at night spikes insulin and disrupts sleep hormones. Eat fruits before sunset.", 'hi': "रात में फल खाने से शुगर बढ़ती है और नींद खराब होती है। फल दिन में खाएं।", 'or': "ରାତିରେ ଫଳ ଖାଇଲେ ସୁଗାର୍ ବଢ଼େ | ଦିନରେ ଖାଆନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Milk for Adults", 'hi': "बड़ों के लिए दूध", 'or': "ବଡମାନଙ୍କ ପାଇଁ କ୍ଷୀର"},
    body: {'en': "Many adults are lactose intolerant. If milk gives you gas, stop it. You can get calcium from Ragi and Til (Sesame) instead.", 'hi': "अगर दूध से गैस बनती है, तो दही खाएं। कैल्शियम के लिए तिल और रागी खाएं।", 'or': "କ୍ଷୀର ପିଇଲେ ଗ୍ୟାସ୍ ହେଲେ, ରାଶି ଏବଂ ରାଗି ଖାଆନ୍ତୁ |"},
  ),
  HealthTip(
    category: "Myths",
    title: {'en': "Eating Less", 'hi': "कम खाना", 'or': "କମ୍ ଖାଇବା"},
    body: {'en': "Eating too little puts the body in 'Starvation Mode', storing fat instead of burning it. You need to eat RIGHT, not less.", 'hi': "बहुत कम खाने से शरीर डर जाता है और फैट जमा करने लगता है। सही खाएं, कम नहीं।", 'or': "ବହୁତ କମ୍ ଖାଇଲେ ଶରୀର ଚର୍ବି ଜମା କରେ |"},
  ),

  // ==========================================
  // 13. THE FINAL PITCH (WHY MNT?)
  // ==========================================
  HealthTip(
    category: "General",
    title: {'en': "Why You Fail", 'hi': "आप क्यों हारते हैं?", 'or': "ଆପଣ କାହିଁକି ହାରୁଛନ୍ତି?"},
    body: {'en': "Google tips are general. Your body is unique. What works for your neighbor might harm you. You need a Clinical Roadmap, not random tips.", 'hi': "इंटरनेट के नुस्खे सबके लिए नहीं होते। आपका शरीर अलग है। आपको विशेषज्ञ की सलाह चाहिए।", 'or': "ଇଣ୍ଟରନେଟ୍ ଦେଖି ଚିକିତ୍ସା କରନ୍ତୁ ନାହିଁ | ଆପଣଙ୍କୁ ବିଶେଷଜ୍ଞଙ୍କ ପରାମର୍ଶ ଦରକାର |"},
  ),
  HealthTip(
    category: "General",
    title: {'en': "Self Medication", 'hi': "खुद डॉक्टर न बनें", 'or': "ନିଜେ ଡାକ୍ତର ହୁଅନ୍ତୁ ନାହିଁ"},
    body: {'en': "Trying to fix hormones with home remedies? You might mess them up further. Hormones are complex chemistry. Trust science.", 'hi': "घरेलू नुस्खों से हार्मोन ठीक नहीं होते, बल्कि और बिगड़ सकते हैं। डॉक्टर पर भरोसा करें।", 'or': "ଘରୋଇ ଉପଚାରରେ ହରମୋନ୍ ଠିକ ହୁଏନି | ବିଶେଷଜ୍ଞଙ୍କ ପରାମର୍ଶ ନିଅନ୍ତୁ |"},
  ),
  HealthTip(
    category: "General",
    title: {'en': "Prevention Cost", 'hi': "सस्ता क्या है?", 'or': "ଶସ୍ତା କଣ?"},
    body: {'en': "Dialysis costs ₹20k/month. Knee replacement ₹4 Lakhs. MNT prevents these disasters. Invest in prevention before disease bankrupts you.", 'hi': "इलाज कराने से बेहतर है बीमारी को आने ही न दें। अस्पताल का खर्चा घर बेच सकता है।", 'or': "ରୋଗ ହେବା ପରେ ଖର୍ଚ୍ଚ କରିବା ଅପେକ୍ଷା ରୋଗ ନ ହେବା ଭଲ |"},
  ),
  HealthTip(
    category: "General",
    title: {'en': "The 3 Month Rule", 'hi': "3 महीने का नियम", 'or': "୩ ମାସର ନିୟମ"},
    body: {'en': "Your blood cells renew every 90 days. Give MNT 3 months, and you will have a biologically new body. No pill can do this.", 'hi': "खून की कोशिकाएं 90 दिन में नई बनती हैं। 3 महीने सही डाइट लें, नया शरीर पाएं।", 'or': "୩ ମାସ ସଠିକ୍ ଖାଦ୍ୟ ଖାଇଲେ ଶରୀର ନୂଆ ହୋଇଯିବ |"},
  ),
  HealthTip(
    category: "General",
    title: {'en': "Don't Wait", 'hi': "इंतजार न करें", 'or': "ଅପେକ୍ଷା କରନ୍ତୁ ନାହିଁ"},
    body: {'en': "Disease doesn't wait for your 'Good Time'. Every day you ignore symptoms, the damage deepens. Book your consultation today.", 'hi': "बीमारी आपके 'अच्छे वक्त' का इंतजार नहीं करती। आज ही अपनी सेहत सुधारें।", 'or': "ରୋଗ ଅପେକ୍ଷା କରେନାହିଁ | ଆଜି ହିଁ ସତର୍କ ହୁଅନ୍ତୁ |"},
  ),
];

// --- FINAL MERGER ---
// This combines all parts into one master list for the app to use
final List<HealthTip> masterHealthTips = [
  ...healthTipsPart1,
  ...healthTipsPart2,
  ...healthTipsPart3,
];