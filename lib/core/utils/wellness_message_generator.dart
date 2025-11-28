import 'dart:math';

class WellnessMessageGenerator {
  static String getMessage({required String type, required String languageCode}) {
    // Normalize language code (e.g., 'en-US' -> 'en')
    final lang = languageCode.split('-').first;
    final list = _content[type]?[lang] ?? _content[type]?['en']!;

    // Pick a random message for variety
    return list![Random().nextInt(list.length)];
  }

  static const Map<String, Map<String, List<String>>> _content = {
    'hydration': {
      'en': [
        "Your body is asking for water. Let's nourish it.",
        "A sip of water now will boost your energy instantly.",
        "Hydration is self-love. Take a moment to drink.",
        "Your brain needs water to focus. Let's grab a glass.",
      ],
      'hi': [
        "आपका शरीर पानी मांग रहा है। इसे पोषण दें।",
        "अभी पानी पीने से आपकी ऊर्जा तुरंत बढ़ जाएगी।",
        "खुद का ख्याल रखना ही असली सेहत है। थोड़ा पानी पिएं।",
        "आपके दिमाग को फोकस करने के लिए पानी की जरूरत है।",
      ],
      'or': [
        "ଆପଣଙ୍କ ଶରୀର ପାଣି ମାଗୁଛି। ଟିକେ ପିଇନିଅନ୍ତୁ।",
        "ବର୍ତ୍ତମାନ ପାଣି ପିଇଲେ ଆପଣଙ୍କୁ ଶକ୍ତି ମିଳିବ।",
        "ନିଜର ଯତ୍ନ ନେବା ଜରୁରୀ। ଟିକେ ପାଣି ପିଅନ୍ତୁ।",
      ]
    },
    'steps': {
      'en': [
        "Sitting too long? Let's stretch those legs.",
        "A short walk now can change your whole mood.",
        "Movement is medicine. Let's take 500 steps.",
        "Your heart loves a walk. Shall we go?",
      ],
      'hi': [
        "बहुत देर से बैठे हैं? चलिए थोड़ा टहल लेते हैं।",
        "एक छोटी सी सैर आपका मूड बदल सकती है।",
        "चलना ही असली दवा है। चलिए 500 कदम चलते हैं।",
      ],
      'or': [
        "ବହୁତ ସମୟ ବସି ରହିଛନ୍ତି କି? ଚାଲନ୍ତୁ ଟିକେ ବୁଲି ଆସିବା।",
        "ଅଳ୍ପ ଚାଲିଲେ ଆପଣଙ୍କ ମନ ଭଲ ହୋଇଯିବ।",
        "ଚାଲିବା ସ୍ୱାସ୍ଥ୍ୟ ପାଇଁ ଭଲ। ଚାଲନ୍ତୁ କିଛି ପାଦ ଚାଲିବା।",
      ]
    },
    'medicine': {
      'en': [
        "It's time for your healing dose. Take care.",
        "Your health is priority. Don't forget your medicine.",
      ],
      'hi': [
        "यह आपकी दवा का समय है। अपना ख्याल रखें।",
        "आपकी सेहत सबसे जरूरी है। दवा लेना न भूलें।",
      ],
      'or': [
        "ଔଷଧ ଖାଇବାର ସମୟ ହୋଇଗଲାଣି।",
        "ନିଜ ସ୍ୱାସ୍ଥ୍ୟର ଯତ୍ନ ନିଅନ୍ତୁ। ଔଷଧ ଖାଇବାକୁ ଭୁଲନ୍ତୁ ନାହିଁ।",
      ]
    }
  };
}