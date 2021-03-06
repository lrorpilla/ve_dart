/// Copyright (c) 2021 Leo Rafael Orpilla
/// MIT License
///
/// A Dart implementation of Ve.
/// A linguistic framework that's easy to use.
/// No degree required.
///
/// Based on the Java port by Jamie Birch.

import 'package:mecab_dart/mecab_dart.dart';
import 'package:ve_dart/ve_dart.dart';

List<Word> parseVe(Mecab tagger, String text) {
  List<dynamic> dynamicTokens = tagger.parse(text);
  List<TokenNode> tokens = dynamicTokens.map((n) => n as TokenNode).toList();

  // Sometimes mecab_dart doesn't print the appropriate length so we
  // generate dummy values for all tokens short of the right length
  for (TokenNode token in tokens) {
    for (int i = 0; i < 9 - token.features.length; i++) {
      token.features.add('*');
    }
  }

  Parse parse = Parse(tokens);
  return parse.words();
}

class Parse {
  static const String NO_DATA = "*";

  static const int POS1 = 0;
  static const int POS2 = 1;
  static const int POS3 = 2;
  static const int POS4 = 3;
  static const int CTYPE = 4;
  static const int CFORM = 5;
  static const int BASIC = 6;
  static const int READING = 7;
  static const int PRONUNCIATION = 8;

  List<TokenNode> tokenArray = [];

  Parse(List<TokenNode> tokenArray) {
    if (tokenArray.length == 0)
      throw new Exception("Cannot parse an empty array of tokens.");

    this.tokenArray = tokenArray;
  }

  List<String> getFeaturesToCheck(TokenNode node) {
    List<String> featuresToCheck = [];

    for (int i = POS1; i < POS4 + 1; i++) {
      featuresToCheck.add(node.features[i].toString());
    }
    return featuresToCheck;
  }

  List<Word> words() {
    List<Word> wordList = [];
    TokenNode? current;
    TokenNode? previous;
    TokenNode? following;

    for (int i = 0; i < tokenArray.length - 1; i++) {
      int finalSlot = wordList.length - 1;
      current = tokenArray[i];
      Pos pos; // could make this TBD instead.
      Grammar grammar = Grammar.Unassigned;
      bool eatNext = false;
      bool eatLemma = true;
      bool attachToPrevious = false;
      bool alsoAttachToLemma = false;
      bool updatePos = false;

      List<String> currentPOSArray = getFeaturesToCheck(current);

      if (currentPOSArray.length == 0 || currentPOSArray[POS1] == NO_DATA)
        throw new Exception("No Pos data found for token.");

      switch (currentPOSArray[POS1]) {
        case MEISHI:
//                case MICHIGO:
          pos = Pos.Noun;
          if (currentPOSArray[POS2] == NO_DATA) {
            break;
          }

          switch (currentPOSArray[POS2]) {
            case KOYUUMEISHI:
              pos = Pos.ProperNoun;
              break;
            case DAIMEISHI:
              pos = Pos.Pronoun;
              break;
            case FUKUSHIKANOU:
            case SAHENSETSUZOKU:
            case KEIYOUDOUSHIGOKAN:
            case NAIKEIYOUSHIGOKAN:
              // Refers to line 213 of Ve.
              if (currentPOSArray[POS3] == NO_DATA) {
                break;
              }
              if (i == tokenArray.length - 1) {
                break; // protects against array overshooting.
              }

              following = tokenArray[i + 1];
              switch (following.features[CTYPE]) {
                case SAHEN_SURU:
                  pos = Pos.Verb;
                  eatNext = true;
                  break;
                case TOKUSHU_DA:
                  pos = Pos.Adjective;
                  if (getFeaturesToCheck(following)[POS2] == TAIGENSETSUZOKU) {
                    eatNext = true;
                    eatLemma = false;
                  }
                  break;
                case TOKUSHU_NAI:
                  pos = Pos.Adjective;
                  eatNext = true;
                  break;
                default:
                  if (getFeaturesToCheck(following)[POS2] == JOSHI &&
                      following.surface == NI) {
                    pos = Pos.Adverb;
                  }
              }
              break;
            case HIJIRITSU:
            case TOKUSHU:
              // Refers to line 233 of Ve.
              if (currentPOSArray[POS3] == NO_DATA) {
                break;
              }
              if (i == tokenArray.length - 1) {
                break;
              }
              following = tokenArray[i + 1];

              switch (currentPOSArray[POS3]) {
                case FUKUSHIKANOU:
                  if (getFeaturesToCheck(following)[POS1] == JOSHI &&
                      following.surface == NI) {
                    pos = Pos.Adverb;
                    eatNext = false;
                  }
                  break;
                case JODOUSHIGOKAN:
                  if (following.features[CTYPE] == TOKUSHU_DA) {
                    pos = Pos.Verb;
                    grammar = Grammar.Auxiliary;
                    if (following.features[CFORM] == TAIGENSETSUZOKU) {
                      eatNext = true;
                    }
                  } else if (getFeaturesToCheck(following)[POS1] == JOSHI &&
                      getFeaturesToCheck(following)[POS3] == FUKUSHIKA) {
                    pos = Pos.Adverb;
                    eatNext = true;
                  }
                  break;
                case KEIYOUDOUSHIGOKAN:
                  pos = Pos.Adjective;
                  if (following.features[CTYPE] == TOKUSHU_DA &&
                          following.features[CTYPE] == TAIGENSETSUZOKU ||
                      getFeaturesToCheck(following)[POS2] == RENTAIKA) {
                    eatNext = true;
                  }
                  break;
                default:
                  break;
              }
              break;
            case KAZU:
              // TODO: "recurse and find following numbers and add to this word. Except non-numbers like ???"
              // Refers to line 261.
              pos = Pos.Number;
              if (wordList.length > 0 &&
                  wordList[finalSlot].getPartOfSpeech() == Pos.Number) {
                attachToPrevious = true;
                alsoAttachToLemma = true;
              }
              break;
            case SETSUBI:
              // Refers to line 267.
              if (currentPOSArray[POS3] == JINMEI) {
                pos = Pos.Suffix;
              } else {
                if (currentPOSArray[POS3] == TOKUSHU &&
                    current.features[BASIC] == SA) {
                  updatePos = true;
                  pos = Pos.Noun;
                } else
                  alsoAttachToLemma = true;
                attachToPrevious = true;
              }
              break;
            case SETSUZOKUSHITEKI:
              pos = Pos.Conjunction;
              break;
            case DOUSHIHIJIRITSUTEKI:
              pos = Pos.Verb;
              grammar = Grammar.Nominal; // not using.
              break;
            default:
              // Keep Pos as Noun, as it currently is.
              break;
          }
          break;
        case SETTOUSHI:
          // TODO: "elaborate this when we have the "main part" feature for words?"
          pos = Pos.Prefix;
          break;
        case JODOUSHI:
          // Refers to line 290.
          pos = Pos.Postposition;
          const List<String> qualifyingList1 = [
            TOKUSHU_TA,
            TOKUSHU_NAI,
            TOKUSHU_TAI,
            TOKUSHU_MASU,
            TOKUSHU_NU
          ];
          if (previous == null ||
              !(getFeaturesToCheck(previous)[POS2] == KAKARIJOSHI) &&
                  qualifyingList1.contains(current.features[CTYPE]))
            attachToPrevious = true;
          else if (current.features[CTYPE] == FUHENKAGATA &&
              current.features[BASIC] == NN)
            attachToPrevious = true;
          else if (current.features[CTYPE] == TOKUSHU_DA ||
              current.features[CTYPE] == TOKUSHU_DESU &&
                  !(current.surface == NA)) pos = Pos.Verb;
          break;
        case DOUSHI:
          // Refers to line 299.
          pos = Pos.Verb;
          switch (currentPOSArray[POS2]) {
            case SETSUBI:
              attachToPrevious = true;
              break;
            case HIJIRITSU:
              if (current.features[CFORM] != MEIREI_I) {
                attachToPrevious = true;
              }
              break;
            default:
              break;
          }
          break;
        case KEIYOUSHI:
          pos = Pos.Adjective;
          break;
        case JOSHI:
          // Refers to line 309.
          pos = Pos.Postposition;
          const List<String> qualifyingList2 = [TE, DE, BA]; // added NI
          if (currentPOSArray[POS2] == SETSUZOKUJOSHI &&
                  qualifyingList2.contains(current.surface) ||
              current.surface == NI) {
            attachToPrevious = true;
          }
          break;
        case RENTAISHI:
          pos = Pos.Determiner;
          break;
        case SETSUZOKUSHI:
          pos = Pos.Conjunction;
          break;
        case FUKUSHI:
          pos = Pos.Adverb;
          break;
        case KIGOU:
          pos = Pos.Symbol;
          break;
        case FIRAA:
        case KANDOUSHI:
          pos = Pos.Interjection;
          break;
        case SONOTA:
          pos = Pos.Other;
          break;
        default:
          pos = Pos.TBD;
        // C'est une catastrophe
      }

      if (attachToPrevious && wordList.length > 0) {
        // these sometimes try to add to null readings.
        wordList[finalSlot].getTokens().add(current);
        wordList[finalSlot].appendToWord(current.surface);
        wordList[finalSlot].appendToReading(getFeatureSafely(current, READING));
        wordList[finalSlot]
            .appendToTranscription(getFeatureSafely(current, PRONUNCIATION));
        if (alsoAttachToLemma) {
          wordList[finalSlot]
              .appendToLemma(current.features[BASIC]); // lemma == basic.
        }

        if (updatePos) {
          wordList[finalSlot].setPartOfSpeech(pos);
        }
      } else {
        Word word = new Word(
            getFeatureSafely(current, READING),
            getFeatureSafely(current, PRONUNCIATION),
            grammar,
            current.features[BASIC],
            pos,
            current.surface,
            current);
        if (eatNext) {
          if (i == tokenArray.length - 1) {
            throw new Exception(
                "There's a path that allows array overshooting.");
          }

          following = tokenArray[i + 1];
          word.getTokens().add(following);
          word.appendToWord(following.surface);
          word.appendToReading(getFeatureSafely(following, READING));
          word.appendToTranscription(
              getFeatureSafely(following, PRONUNCIATION));
          if (eatLemma) {
            word.appendToLemma(following.features[BASIC]);
          }
        }
        wordList.add(word);
      }
      previous = current;
    }

    return wordList;
  }

  String getFeatureSafely(TokenNode token, int feature) {
    if (feature > PRONUNCIATION) {
      throw new Exception("Asked for a feature out of bounds.");
    }

    return token.features.length >= feature + 1 ? token.features[feature] : "*";
  }

  // POS1
  static const String MEISHI = "??????";
  static const String KOYUUMEISHI = "????????????";
  static const String DAIMEISHI = "?????????";
  static const String JODOUSHI = "?????????";
  static const String KAZU = "???";
  static const String JOSHI = "??????";
  static const String SETTOUSHI = "?????????";
  static const String DOUSHI = "??????";
  static const String KIGOU = "??????";
  static const String FIRAA = "????????????";
  static const String SONOTA = "?????????";
  static const String KANDOUSHI = "?????????";
  static const String RENTAISHI = "?????????";
  static const String SETSUZOKUSHI = "?????????";
  static const String FUKUSHI = "??????";
  static const String SETSUZOKUJOSHI = "????????????";
  static const String KEIYOUSHI = "?????????";
  static const String MICHIGO = "?????????";

  // POS2_BLACKLIST and inflection types
  static const String HIJIRITSU = "?????????";
  static const String FUKUSHIKANOU = "????????????";
  static const String SAHENSETSUZOKU = "????????????";
  static const String KEIYOUDOUSHIGOKAN = "??????????????????";
  static const String NAIKEIYOUSHIGOKAN = "?????????????????????";
  static const String JODOUSHIGOKAN = "???????????????";
  static const String FUKUSHIKA = "?????????";
  static const String TAIGENSETSUZOKU = "????????????";
  static const String RENTAIKA = "?????????";
  static const String TOKUSHU = "??????";
  static const String SETSUBI = "??????";
  static const String SETSUZOKUSHITEKI = "????????????";
  static const String DOUSHIHIJIRITSUTEKI = "??????????????????";
  static const String SAHEN_SURU = "???????????????";
  static const String TOKUSHU_TA = "????????????";
  static const String TOKUSHU_NAI = "???????????????";
  static const String TOKUSHU_TAI = "???????????????";
  static const String TOKUSHU_DESU = "???????????????";
  static const String TOKUSHU_DA = "????????????";
  static const String TOKUSHU_MASU = "???????????????";
  static const String TOKUSHU_NU = "????????????";
  static const String FUHENKAGATA = "????????????";
  static const String JINMEI = "??????";
  static const String MEIREI_I = "?????????";
  static const String KAKARIJOSHI = "?????????";
  static const String KAKUJOSHI = "?????????";

  // etc
  static const String NA = "???";
  static const String NI = "???";
  static const String TE = "???";
  static const String DE = "???";
  static const String BA = "???";
  static const String NN = "???";
  static const String SA = "???";
}
