import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// --------------------------------------------------------------------
// 🌍 TRANSLATION DICTIONARY (UI LOCALIZATION)
// --------------------------------------------------------------------
final Map<String, Map<String, String>> localizedStrings = {
  'en': {
    'app_title': 'Hands-Free Song Identifier',
    'where_are_you': 'Where Are You?',
    'quiet_room': 'A quiet room',
    'loud_room': 'A loud room with background noise',
    'skiing': 'Skiing',
    'initial_status': 'Select your environment and tap the mic or squeeze AirPods stem!',
    'listening': 'Listening...',
    'searching': 'Searching database...',
    'match_found': 'Match Found!',
    'mic_denied': 'Microphone permission denied.',
    'settings_title': 'App Preferences',
    'pref_music_app': 'Preferred Music App',
    'pref_lang': 'Preferred Language',
    'open_spotify': 'Open in Spotify App',
    'open_apple': 'Open in Apple Music',
    'history_title': 'Search History',
    'clear_history': 'Clear History',
    'clear_history_confirm': 'Are you sure you want to delete all saved song searches?',
    'no_history': 'No songs searched yet!',
    'cancel': 'Cancel',
    'save': 'Save',
    'clear': 'Clear',
    'tip': '💡 Tip: Say "Hey Siri, find song with Reczt" to open the app and instantly start finding the song stuck in your head!',
    'by': 'by',
  },
  'es': {
    'app_title': 'Identificador de Canciones',
    'where_are_you': '¿Dónde estás?',
    'quiet_room': 'Una habitación silenciosa',
    'loud_room': 'Una habitación ruidosa con ruido de fondo',
    'skiing': 'Esquiando',
    'initial_status': '¡Selecciona tu entorno y toca el micrófono o presiona tus AirPods!',
    'listening': 'Escuchando...',
    'searching': 'Buscando en la base de datos...',
    'match_found': '¡Coincidencia encontrada!',
    'mic_denied': 'Permiso de micrófono denegado.',
    'settings_title': 'Preferencias de la aplicación',
    'pref_music_app': 'Aplicación de música preferida',
    'pref_lang': 'Idioma preferido',
    'open_spotify': 'Abrir en Spotify',
    'open_apple': 'Abrir en Apple Music',
    'history_title': 'Historial de búsqueda',
    'clear_history': 'Borrar historial',
    'clear_history_confirm': '¿Estás seguro de que deseas eliminar todas las búsquedas guardadas?',
    'no_history': '¡Aún no has buscado canciones!',
    'cancel': 'Cancelar',
    'save': 'Guardar',
    'clear': 'Borrar',
    'tip': '💡 Consejo: Di "Oye Siri, buscar canción con Reczt" para abrir la aplicación e identificar la canción.',
    'by': 'de',
  },
  'fr': {
    'app_title': 'Identificateur de Chansons',
    'where_are_you': 'Où êtes-vous ?',
    'quiet_room': 'Une pièce calme',
    'loud_room': 'Une pièce bruyante avec du bruit de fond',
    'skiing': 'En train de skier',
    'initial_status': 'Sélectionnez votre environnement et appuyez sur le micro !',
    'listening': 'Écoute en cours...',
    'searching': 'Recherche dans la base de données...',
    'match_found': 'Correspondance trouvée !',
    'mic_denied': 'Autorisation du microphone refusée.',
    'settings_title': 'Préférences de l\'application',
    'pref_music_app': 'Application musicale préférée',
    'pref_lang': 'Langue préférée',
    'open_spotify': 'Ouvrir dans Spotify',
    'open_apple': 'Ouvrir dans Apple Music',
    'history_title': 'Historique des recherches',
    'clear_history': 'Effacer l\'historique',
    'clear_history_confirm': 'Voulez-vous vraiment supprimer toutes les recherches enregistrées ?',
    'no_history': 'Aucune chanson recherchée pour l\'instant !',
    'cancel': 'Annuler',
    'save': 'Enregistrer',
    'clear': 'Effacer',
    'tip': '💡 Astuce : Dites "Dis Siri, trouve la chanson avec Reczt" pour démarrer !',
    'by': 'par',
  },
  'de': {
    'app_title': 'Song-Erkennung',
    'where_are_you': 'Wo bist du?',
    'quiet_room': 'Ein ruhiger Raum',
    'loud_room': 'Ein lauter Raum mit Hintergrundgeräuschen',
    'skiing': 'Skifahren',
    'initial_status': 'Wähle deine Umgebung und tippe auf das Mikrofon!',
    'listening': 'Zuhören...',
    'searching': 'Datenbank wird durchsucht...',
    'match_found': 'Treffer gefunden!',
    'mic_denied': 'Mikrofonberechtigung verweigert.',
    'settings_title': 'App-Einstellungen',
    'pref_music_app': 'Bevorzugte Musik-App',
    'pref_lang': 'Bevorzugte Sprache',
    'open_spotify': 'In Spotify öffnen',
    'open_apple': 'In Apple Music öffnen',
    'history_title': 'Suchverlauf',
    'clear_history': 'Verlauf löschen',
    'clear_history_confirm': 'Möchtest du wirklich alle gespeicherten Suchen löschen?',
    'no_history': 'Noch keine Songs gesucht!',
    'cancel': 'Abbrechen',
    'save': 'Speichern',
    'clear': 'Löschen',
    'tip': '💡 Tipp: Sage "Hey Siri, finde Song mit Reczt", um sofort zu starten!',
    'by': 'von',
  },
  'it': {
    'app_title': 'Riconoscimento Brani',
    'where_are_you': 'Dove ti trovi?',
    'quiet_room': 'Una stanza silenziosa',
    'loud_room': 'Una stanza rumorosa',
    'skiing': 'Sciare',
    'initial_status': 'Seleziona l\'ambiente e tocca il microfono!',
    'listening': 'Ascolto in corso...',
    'searching': 'Ricerca nel database...',
    'match_found': 'Brano trovato!',
    'mic_denied': 'Autorizzazione microfono negata.',
    'settings_title': 'Preferenze App',
    'pref_music_app': 'App musicale preferita',
    'pref_lang': 'Lingua preferita',
    'open_spotify': 'Apri su Spotify',
    'open_apple': 'Apri su Apple Music',
    'history_title': 'Cronologia ricerche',
    'clear_history': 'Cancella cronologia',
    'clear_history_confirm': 'Sei sicuro di voler eliminare tutta la cronologia?',
    'no_history': 'Nessun brano cercato finora!',
    'cancel': 'Annulla',
    'save': 'Salva',
    'clear': 'Cancella',
    'tip': '💡 Consiglio: Dì "Ehi Siri, trova canzone con Reczt"!',
    'by': 'di',
  },
  'pt': {
    'app_title': 'Identificador de Músicas',
    'where_are_you': 'Onde você está?',
    'quiet_room': 'Um quarto silencioso',
    'loud_room': 'Um ambiente barulhento',
    'skiing': 'Esquiando',
    'initial_status': 'Selecione seu ambiente e toque no microfone!',
    'listening': 'Ouvindo...',
    'searching': 'Buscando no banco de dados...',
    'match_found': 'Música encontrada!',
    'mic_denied': 'Permissão do microfone negada.',
    'settings_title': 'Preferências do App',
    'pref_music_app': 'App de música preferido',
    'pref_lang': 'Idioma preferido',
    'open_spotify': 'Abrir no Spotify',
    'open_apple': 'Abrir no Apple Music',
    'history_title': 'Histórico de busca',
    'clear_history': 'Limpar histórico',
    'clear_history_confirm': 'Tem certeza que deseja apagar o histórico?',
    'no_history': 'Nenhuma música buscada ainda!',
    'cancel': 'Cancelar',
    'save': 'Salvar',
    'clear': 'Limpar',
    'tip': '💡 Dica: Diga "Eaí Siri, buscar música com Reczt"!',
    'by': 'de',
  },
  'ja': {
    'app_title': '楽曲識別アプリ',
    'where_are_you': 'どこにいますか？',
    'quiet_room': '静かな部屋',
    'loud_room': '騒がしい場所',
    'skiing': 'スキー中',
    'initial_status': '環境を選択してマイクをタップしてください！',
    'listening': '聞き取り中...',
    'searching': 'データベースを検索中...',
    'match_found': '曲が見つかりました！',
    'mic_denied': 'マイクのアクセス許可が拒否されました。',
    'settings_title': 'アプリ設定',
    'pref_music_app': '優先音楽アプリ',
    'pref_lang': '優先言語',
    'open_spotify': 'Spotifyで開く',
    'open_apple': 'Apple Musicで開く',
    'history_title': '検索履歴',
    'clear_history': '履歴を消去',
    'clear_history_confirm': 'すべての検索履歴を削除しますか？',
    'no_history': 'まだ検索された曲はありません！',
    'cancel': 'キャンセル',
    'save': '保存',
    'clear': '消去',
    'tip': '💡 ヒント：「Hey Siri、Recztで曲を探して」と言ってみよう！',
    'by': 'アーティスト:',
  },
  'ko': {
    'app_title': '음악 검색 식별기',
    'where_are_you': '어디에 계신가요?',
    'quiet_room': '조용한 방',
    'loud_room': '시끄러운 장소',
    'skiing': '스키 타는 중',
    'initial_status': '환경을 선택하고 마이크를 탭하세요!',
    'listening': '듣는 중...',
    'searching': '데이터베이스 검색 중...',
    'match_found': '곡을 찾았습니다!',
    'mic_denied': '마이크 권한이 거부되었습니다.',
    'settings_title': '앱 설정',
    'pref_music_app': '선호하는 음악 앱',
    'pref_lang': '선호하는 언어',
    'open_spotify': 'Spotify에서 열기',
    'open_apple': 'Apple Music에서 열기',
    'history_title': '검색 기록',
    'clear_history': '기록 삭제',
    'clear_history_confirm': '모든 검색 기록을 삭제하시겠습니까?',
    'no_history': '아직 검색한 노래가 없습니다!',
    'cancel': '취소',
    'save': '저장',
    'clear': '삭제',
    'tip': '💡 팁: "Siri야, Reczt로 노래 찾아줘"라고 말해보세요!',
    'by': '아티스트:',
  },
  'zh': {
    'app_title': '歌曲识别器',
    'where_are_you': '你在哪里？',
    'quiet_room': '安静的房间',
    'loud_room': '吵闹的环境',
    'skiing': '滑雪中',
    'initial_status': '选择你的环境并轻按麦克风！',
    'listening': '正在聆听...',
    'searching': '正在搜索数据库...',
    'match_found': '找到歌曲！',
    'mic_denied': '麦克风权限被拒绝。',
    'settings_title': '应用设置',
    'pref_music_app': '首选音乐应用',
    'pref_lang': '首选语言',
    'open_spotify': '在 Spotify 中打开',
    'open_apple': '在 Apple Music 中打开',
    'history_title': '搜索历史',
    'clear_history': '清除历史',
    'clear_history_confirm': '确定要删除所有搜索记录吗？',
    'no_history': '还没有搜索过歌曲！',
    'cancel': '取消',
    'save': '保存',
    'clear': '清除',
    'tip': '💡 提示：对 Siri 说“Hey Siri，用 Reczt 找歌”！',
    'by': '歌手：',
  },
  'hi': {
    'app_title': 'गाना पहचानें',
    'where_are_you': 'आप कहाँ हैं?',
    'quiet_room': 'शांत कमरा',
    'loud_room': 'शोर-शराबे वाली जगह',
    'skiing': 'स्कीइंग',
    'initial_status': 'पर्यावरण चुनें और माइक पर टैप करें!',
    'listening': 'सुन रहा है...',
    'searching': 'डेटाबेस में खोज रहा है...',
    'match_found': 'गाना मिल गया!',
    'mic_denied': 'माइक अनुमति अस्वीकृत।',
    'settings_title': 'ऐप प्राथमिकताएं',
    'pref_music_app': 'पसंदीदा म्यूजिक ऐप',
    'pref_lang': 'पसंदीदा भाषा',
    'open_spotify': 'Spotify में खोलें',
    'open_apple': 'Apple Music में खोलें',
    'history_title': 'खोज इतिहास',
    'clear_history': 'इतिहास मिटाएं',
    'clear_history_confirm': 'क्या आप सभी खोज इतिहास को हटाना चाहते हैं?',
    'no_history': 'अभी तक कोई गाना नहीं खोजा गया!',
    'cancel': 'रद्द करें',
    'save': 'सहेजें',
    'clear': 'मिटाएं',
    'tip': '💡 सुझाव: "Hey Siri, Reczt से गाना खोजो" कहें!',
    'by': 'द्वारा',
  },
  'ru': {
    'app_title': 'Распознавание Музыки',
    'where_are_you': 'Где вы находитесь?',
    'quiet_room': 'Тихая комната',
    'loud_room': 'Шумное помещение',
    'skiing': 'Катание на лыжах',
    'initial_status': 'Выберите обстановку и нажмите на микрофон!',
    'listening': 'Слушаю...',
    'searching': 'Поиск в базе данных...',
    'match_found': 'Песня найдена!',
    'mic_denied': 'Доступ к микрофону запрещен.',
    'settings_title': 'Настройки приложения',
    'pref_music_app': 'Предпочитаемый плеер',
    'pref_lang': 'Предпочитаемый язык',
    'open_spotify': 'Открыть в Spotify',
    'open_apple': 'Открыть в Apple Music',
    'history_title': 'История поиска',
    'clear_history': 'Очистить историю',
    'clear_history_confirm': 'Вы уверены, что хотите удалить историю поиска?',
    'no_history': 'Вы еще не искали песни!',
    'cancel': 'Отмена',
    'save': 'Сохранить',
    'clear': 'Очистить',
    'tip': '💡 Совет: Скажите "Привет, Siri, найди песню через Reczt"!',
    'by': 'исполнитель',
  },
  'tr': {
    'app_title': 'Şarkı Tanıma',
    'where_are_you': 'Neredesiniz?',
    'quiet_room': 'Sessiz bir oda',
    'loud_room': 'Gürültülü bir ortam',
    'skiing': 'Kayak yaparken',
    'initial_status': 'Ortamınızı seçin ve mikrofona dokunun!',
    'listening': 'Dinleniyor...',
    'searching': 'Veritabanı aranıyor...',
    'match_found': 'Eşleşme Bulundu!',
    'mic_denied': 'Mikrofon izni reddedildi.',
    'settings_title': 'Uygulama Tercihleri',
    'pref_music_app': 'Tercih Edilen Müzik Uygulaması',
    'pref_lang': 'Tercih Edilen Dil',
    'open_spotify': 'Spotify\'da Aç',
    'open_apple': 'Apple Music\'te Aç',
    'history_title': 'Arama Geçmişi',
    'clear_history': 'Geçmişi Temizle',
    'clear_history_confirm': 'Tüm arama geçmişini silmek istediğinize emin misiniz?',
    'no_history': 'Henüz şarkı aranmadı!',
    'cancel': 'İptal',
    'save': 'Kaydet',
    'clear': 'Temizle',
    'tip': '💡 İpucu: "Hey Siri, Reczt ile şarkı bul" deyin!',
    'by': 'sanatçı',
  },
  'ar': {
    'app_title': 'محدد الأغاني',
    'where_are_you': 'أين أنت؟',
    'quiet_room': 'غرفة هادئة',
    'loud_room': 'مكان صاخب',
    'skiing': 'التزلج',
    'initial_status': 'حدد بيئتك واضغط على الميكروفون!',
    'listening': 'جاري الاستماع...',
    'searching': 'جاري البحث...',
    'match_found': 'تم العثور على الأغنية!',
    'mic_denied': 'تم رفض إذن الميكروفون.',
    'settings_title': 'تفضيلات التطبيق',
    'pref_music_app': 'تطبيق الموسيقى المفضل',
    'pref_lang': 'اللغة المفضلة',
    'open_spotify': 'فتح في Spotify',
    'open_apple': 'فتح في Apple Music',
    'history_title': 'سجل البحث',
    'clear_history': 'مسح السجل',
    'clear_history_confirm': 'هل أنت تأكد من رغبتك في حذف جميع عمليات البحث؟',
    'no_history': 'لم يتم البحث عن أغاني بعد!',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'clear': 'مسح',
    'tip': '💡 تلميح: قل "يا Siri، ابحث عن أغنية باستخدام Reczt"!',
    'by': 'بواسطة',
  },
  'nl': {
    'app_title': 'Nummer Herkenner',
    'where_are_you': 'Waar ben je?',
    'quiet_room': 'Een stille ruimte',
    'loud_room': 'Een drukke ruimte',
    'skiing': 'Skiën',
    'initial_status': 'Kies je omgeving en tik op de microfoon!',
    'listening': 'Luisteren...',
    'searching': 'Database zoeken...',
    'match_found': 'Nummer Gevonden!',
    'mic_denied': 'Microfoontoegang geweigerd.',
    'settings_title': 'App Voorkeuren',
    'pref_music_app': 'Voorkeurs Muziek App',
    'pref_lang': 'Voorkeurstaal',
    'open_spotify': 'Openen in Spotify',
    'open_apple': 'Openen in Apple Music',
    'history_title': 'Zoekgeschiedenis',
    'clear_history': 'Geschiedenis Wissselen',
    'clear_history_confirm': 'Weet je zeker dat je alle zoekopdrachten wilt wissselen?',
    'no_history': 'Nog geen nummers gezocht!',
    'cancel': 'Annuleren',
    'save': 'Opslaan',
    'clear': 'Wissselen',
    'tip': '💡 Tip: Zeg "Hey Siri, vind nummer met Reczt"!',
    'by': 'door',
  },
  'pl': {
    'app_title': 'Rozpoznawanie Muzyki',
    'where_are_you': 'Gdzie jesteś?',
    'quiet_room': 'Ciche pomieszczenie',
    'loud_room': 'Głośne otoczenie',
    'skiing': 'Jazda na nartach',
    'initial_status': 'Wybierz otoczenie i dotknij mikrofonu!',
    'listening': 'Słucham...',
    'searching': 'Wyszukiwanie w bazie...',
    'match_found': 'Znaleziono utwór!',
    'mic_denied': 'Odmowa dostępu do mikrofonu.',
    'settings_title': 'Preferencje Aplikacji',
    'pref_music_app': 'Preferowana aplikacja muzyczna',
    'pref_lang': 'Preferowany język',
    'open_spotify': 'Otwórz w Spotify',
    'open_apple': 'Otwórz w Apple Music',
    'history_title': 'Historia wyszukiwania',
    'clear_history': 'Wyczyść historię',
    'clear_history_confirm': 'Czy na pewno chcesz usunąć całą historię?',
    'no_history': 'Nie wyszukano jeszcze żadnych piosenek!',
    'cancel': 'Anuluj',
    'save': 'Zapisz',
    'clear': 'Wyczyść',
    'tip': '💡 Wskazówka: Powiedz "Hey Siri, znajdź piosenkę z Reczt"!',
    'by': 'wykonawca',
  },
};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hands-Free Song Identifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AudioRecorderScreen(),
    );
  }
}

enum EnvironmentMode {
  quiet(duration: 6, icon: Icons.king_bed, key: 'quiet_room'),
  loud(duration: 8, icon: Icons.volume_up, key: 'loud_room'),
  skiing(duration: 12, icon: Icons.downhill_skiing, key: 'skiing');

  final int duration;
  final IconData icon;
  final String key;

  const EnvironmentMode({
    required this.duration,
    required this.icon,
    required this.key,
  });
}

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen>
    with WidgetsBindingObserver {

  // IMPORTANT: Ensure this string matches AppDelegate.swift exactly!
  static const MethodChannel _siriChannel =
      MethodChannel('com.handsfreefinder/siri');

  @override
  void initState() {
    super.initState();

    AudioPlayer.global.setAudioContext(AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: {
        AVAudioSessionOptions.defaultToSpeaker,
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.allowBluetooth,
        AVAudioSessionOptions.allowBluetoothA2DP,
  },
    ),
  ));

    // Register lifecycle observer for Siri background-to-foreground triggers
    WidgetsBinding.instance.addObserver(this);

    // Initialize audio players & app settings
    _audioRecorder = AudioRecorder();
    _dingPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    _silencePlayer = AudioPlayer();

    _loadSavedMode();
    _loadPreferences();
    _initSilencePlayer();

    if (!kIsWeb) {
      _initAirPodsListener();
      _initSiriListener();
    }

    // Set up Siri handler and check cold-start trigger
    _siriChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSiriTrigger') {
        _checkAndStartSiriRecording();
      }
    });

    _checkAndStartSiriRecording();
  }

   @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    _dingPlayer.dispose();
    _errorPlayer.dispose();
    _silencePlayer.dispose();
    super.dispose();
  }

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    debugPrint("App resumed: ensuring silence player is active...");
    
    // If silence isn't playing, start it up immediately
    if (_silencePlayer.state != PlayerState.playing) {
      _initSilencePlayer();
    }
    
    // Check if Siri opened the app and start recording
    _checkAndStartSiriRecording();
  }
}
 Future<void> _checkAndStartSiriRecording() async {
  try {
    final bool triggered = await _siriChannel.invokeMethod('checkSiriTrigger');

    if (triggered) {
      debugPrint("Siri trigger confirmed!");

      // Make sure silence track is actively running
      if (_silencePlayer.state != PlayerState.playing) {
        await _initSilencePlayer();
      }

      // Briefly pause silence to yield mic access to the recording engine
      await _silencePlayer.pause();
      await Future.delayed(const Duration(milliseconds: 300));

      if (await _audioRecorder.hasPermission()) {
        if (mounted && !_isRecording) {
          _startRecording();
        }
      } else {
        debugPrint("Microphone permission not granted!");
      }
    }
  } catch (e) {
    debugPrint('Error checking Siri trigger: $e');
  }
}

  late final AudioPlayer _dingPlayer;
  late final AudioPlayer _errorPlayer;
  late final AudioPlayer _silencePlayer;
  late final AudioRecorder _audioRecorder;
  AirPodsAudioHandler? _airPodsHandler;

  bool _isRecording = false;
  bool _isLoading = false;

  EnvironmentMode _selectedMode = EnvironmentMode.skiing;
  int _secondsRemaining = 12;
  Timer? _autoStopTimer;
  Timer? _countdownTimer;

  String _preferredMusicApp = 'spotify';
  String _selectedLanguage = 'en';

  final Map<String, String> _languages = {
    'en': '🇺🇸 English',
    'es': '🇪🇸 Español',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'it': '🇮🇹 Italiano',
    'pt': '🇵🇹 Português',
    'ja': '🇯🇵 日本語',
    'ko': '🇰🇷 한국어',
    'zh': '🇨🇳 中文',
    'hi': '🇮🇳 हिन्दी',
    'ru': '🇷🇺 Русский',
    'tr': '🇹🇷 Türkçe',
    'ar': '🇸🇦 العربية',
    'nl': '🇳🇱 Nederlands',
    'pl': '🇵🇱 Polski',
  };

  String _statusTextKey = 'initial_status';
  String? _customStatusText;

  String? _songTitle;
  String? _artist;
  String? _spotifyUrl;
  String? _appleMusicUrl;

  final String _backendUrl =
      'https://song-recognitionapp-cloud.onrender.com/recognize';

  // 1-second high-pitched chime ding sound
  final String _dingAsset = 'ding.mp3';
  final String _errorSoundUrl =
      'https://assets.mixkit.co/active_storage/sfx/2873/2873-preview.mp3';

  // Helper method for localized text
  String t(String key) {
    return localizedStrings[_selectedLanguage]?[key] ??
        localizedStrings['en']![key] ??
        key;
  }


  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApp = prefs.getString('preferred_music_app');
    final savedLang = prefs.getString('preferred_language');

    setState(() {
      _preferredMusicApp = savedApp ?? 'spotify';
      _selectedLanguage = savedLang ?? 'en';
    });

    if (savedApp == null || savedLang == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPreferencesDialog();
      });
    }
  }

  Future<void> _savePreferences(String musicApp, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_music_app', musicApp);
    await prefs.setString('preferred_language', lang);
    setState(() {
      _preferredMusicApp = musicApp;
      _selectedLanguage = lang;
    });
  }

  void _showPreferencesDialog() {
    String tempApp = _preferredMusicApp;
    String tempLang = _selectedLanguage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(t('settings_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('pref_music_app'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Spotify'),
                    value: 'spotify',
                    groupValue: tempApp,
                    onChanged: (val) => setModalState(() => tempApp = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Apple Music'),
                    value: 'apple_music',
                    groupValue: tempApp,
                    onChanged: (val) => setModalState(() => tempApp = val!),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(t('pref_lang'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempLang,
                    items: _languages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => tempLang = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    _savePreferences(tempApp, tempLang);
                    Navigator.pop(context);
                  },
                  child: Text(t('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _initSiriListener() {
    _siriChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSiriTrigger' || call.method == 'triggerSiriRecord') {
        _triggerAutoRecordingFromSiri();
      }
    });

    _siriChannel.invokeMethod<String>('getInitialUrl').then((url) {
      if (url != null && url.isNotEmpty) {
        _triggerAutoRecordingFromSiri();
      }
    }).catchError((e) => debugPrint('Siri initial URL check error: $e'));

    _siriChannel.invokeMethod<bool>('checkSiriTrigger').then((triggered) {
      if (triggered == true) {
        _triggerAutoRecordingFromSiri();
      }
    }).catchError((e) => debugPrint('Siri trigger check error: $e'));
  }

  void _triggerAutoRecordingFromSiri() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isRecording && !_isLoading && mounted) {
        _startRecording(playDing: true);
      }
    });
  }

  Future<void> _initSilencePlayer() async {
  try {
    // Force the silence track to loop continuously
    await _silencePlayer.setReleaseMode(ReleaseMode.loop);
    
    // Explicitly play from assets (starts the audio session immediately)
    await _silencePlayer.play(AssetSource('silence.mp3'));
    debugPrint("Silence track started looping successfully!");
  } catch (e) {
    debugPrint("Error starting silence player: $e");
  }
}
  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('selected_environment_mode');
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < EnvironmentMode.values.length) {
      setState(() {
        _selectedMode = EnvironmentMode.values[savedIndex];
        _secondsRemaining = _selectedMode.duration;
      });
    }
  }

  Future<void> _saveMode(EnvironmentMode mode) async {
    setState(() {
      _selectedMode = mode;
      _secondsRemaining = mode.duration;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_environment_mode', mode.index);
  }

  Future<void> _saveToHistory(String songEntry) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('song_history') ?? [];
    history.insert(0, songEntry);
    await prefs.setStringList('song_history', history);
  }

  Future<void> _initAirPodsListener() async {
    try {
      _airPodsHandler = await AudioService.init(
        builder: () => AirPodsAudioHandler(
          onMediaButtonTriggered: () {
            triggerAirPodsSqueeze();
          },
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.example.song_recognition.channel.audio',
          androidNotificationChannelName: 'AirPods Song Finder',
          androidNotificationOngoing: false,
        ),
      );
    } catch (e) {
      debugPrint('AirPods listener setup notice: $e');
    }
  }


Future<void> _playSingleDing() async {
  try {
    final player = AudioPlayer();
    
    // Use AssetSource instead of UrlSource
    await player.play(AssetSource('ding.mp3')); 
  } catch (e) {
    debugPrint('Error playing ding sound: $e');
  }
}

  Future<void> _playErrorCue() async {
    try {
      await _errorPlayer.play(UrlSource(_errorSoundUrl));
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Error playing failure sound: $e');
    }
  }

  void triggerAirPodsSqueeze() {
    if (!_isRecording && !_isLoading) {
      _startRecording(playDing: false);
    } else if (_isRecording) {
      _stopAndSendRecording();
    }
  }

Future<void> _startRecording({bool playDing = true}) async {
    if (_isRecording || _isLoading) return;

    if (playDing) {
      // Play ding without letting it block the timer if it fails
      _playSingleDing(); 
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _isRecording = true;
      _secondsRemaining = _selectedMode.duration;
      _songTitle = null;
      _artist = null; // Reset timer counter
    });

   _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      }if (_secondsRemaining == 0) {
    timer.cancel();
    _stopAndSendRecording();
  }
});
    try {

      String filePath = '';
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        filePath = '${directory.path}/recording.wav';
      }

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: filePath,
      );
    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      setState(() {
        _isRecording = false;
        _isLoading = true;
        _statusTextKey = 'searching';
        _customStatusText = null;
      });

      final path = await _audioRecorder.stop();
      _silencePlayer.resume();

      if (path != null && path.isNotEmpty) {
        await _sendAudioToBackend(path);
      } else {
        setState(() {
          _isLoading = false;
          _customStatusText = 'Error: Path was empty.';
        });
        _playErrorCue();
      }
    } catch (e) {
      _silencePlayer.resume();
      setState(() {
        _isLoading = false;
        _customStatusText = 'Error stopping: $e';
      });
      _playErrorCue();
    }
  }

  Future<void> _sendAudioToBackend(String path) async {
    final uri = Uri.parse(_backendUrl);
    var request = http.MultipartRequest('POST', uri);

    request.fields['language'] = _selectedLanguage;

    try {
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        final bytes = response.bodyBytes;
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: 'recording.wav'),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final String title = data['title'] ?? 'Unknown Title';
          final String artist = data['artist'] ?? 'Unknown Artist';

          setState(() {
            _songTitle = title;
            _artist = artist;
            _spotifyUrl = data['spotify_url'];
            _appleMusicUrl = data['apple_music_url'];
            _statusTextKey = 'match_found';
            _customStatusText = null;
          });

          await _saveToHistory('$title - $artist');

          if (_preferredMusicApp == 'apple_music' &&
              _appleMusicUrl != null &&
              _appleMusicUrl!.isNotEmpty) {
            _openMusicUrl(_appleMusicUrl!);
          } else if (_spotifyUrl != null && _spotifyUrl!.isNotEmpty) {
            _openSpotifyNative(_spotifyUrl!);
          }
        } else {
          _playErrorCue();
          setState(() {
            _customStatusText = data['message'] ?? 'No match found.';
          });
        }
      } else {
        _playErrorCue();
        setState(() {
          _customStatusText = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      _playErrorCue();
      setState(() {
        _isLoading = false;
        _customStatusText = 'Failed to connect: $e';
      });
    }
  }

  Future<void> _openSpotifyNative(String url) async {
    String finalUrl = url;
    if (url.startsWith('spotify:track:')) {
      final trackId = url.replaceFirst('spotify:track:', '');
      finalUrl = 'spotify:track:$trackId';
    }
    _openMusicUrl(finalUrl);
  }

  Future<void> _openMusicUrl(String url) async {
    try {
      await _silencePlayer.stop();
    } catch (e) {
      debugPrint('Error stopping silence player: $e');
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _getDisplayStatusText() {
    if (_customStatusText != null) {
      return _customStatusText!;
    }
    if (_isRecording) {
      return '${t('listening')} (${_secondsRemaining}s)';
    }
    return t(_statusTextKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('app_title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: t('settings_title'),
            onPressed: _showPreferencesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: t('history_title'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => HistoryPage(lang: _selectedLanguage)),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t('where_are_you'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: EnvironmentMode.values.map((mode) {
                  final isSelected = _selectedMode == mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: InkWell(
                      onTap: _isRecording || _isLoading
                          ? null
                          : () {
                              _saveMode(mode);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.deepPurple.shade50
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mode.icon,
                              color: isSelected
                                  ? Colors.deepPurple
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t(mode.key),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.deepPurple
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${mode.duration}s',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text(
                _getDisplayStatusText(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopAndSendRecording();
                    } else {
                      _startRecording(playDing: true);
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor:
                        _isRecording ? Colors.red : Colors.deepPurple,
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  t('tip'),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              if (_songTitle != null && _artist != null) ...[
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.music_note,
                            size: 60, color: Colors.deepPurple),
                        const SizedBox(height: 12),
                        Text(
                          _songTitle!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${t('by')} $_artist',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (_preferredMusicApp == 'apple_music' &&
                            _appleMusicUrl != null &&
                            _appleMusicUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFA243C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _openMusicUrl(_appleMusicUrl!),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('open_apple')),
                          )
                        else if (_spotifyUrl != null &&
                            _spotifyUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _openSpotifyNative(_spotifyUrl!),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('open_spotify')),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// LOCALIZED SEARCH HISTORY PAGE
// ----------------------------------------------------
class HistoryPage extends StatefulWidget {
  final String lang;
  const HistoryPage({super.key, required this.lang});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<String> _history = [];

  String t(String key) {
    return localizedStrings[widget.lang]?[key] ??
        localizedStrings['en']![key] ??
        key;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('song_history') ?? [];
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('song_history');
    setState(() {
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('history_title')),
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: t('clear_history'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t('clear_history')),
                    content: Text(t('clear_history_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('cancel')),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        child: Text(t('clear'),
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Text(
                t('no_history'),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final songEntry = _history[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 6.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.music_note, color: Colors.white),
                    ),
                    title: Text(
                      songEntry,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ----------------------------------------------------
// AIRPODS AUDIO HANDLER
// ----------------------------------------------------
class AirPodsAudioHandler extends BaseAudioHandler {
  final VoidCallback onMediaButtonTriggered;

  AirPodsAudioHandler({required this.onMediaButtonTriggered}) {
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.play, MediaControl.pause],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
        },
        processingState: AudioProcessingState.ready,
        playing: true,
      ),
    );
  }

  @override
  Future<void> play() async {
    onMediaButtonTriggered();
    return super.play();
  }

  @override
  Future<void> pause() async {
    onMediaButtonTriggered();
    return super.pause();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    onMediaButtonTriggered();
    return super.click(button);
  }
}