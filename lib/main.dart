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
    'by': 'by',
    'User Manual': 'User Manual',
    'step 1': 'Configure Your Settings',
    'step1_desc': 'Select your preferred music platform and language.',
    'step 2': 'Where Are You?',
    'step2_desc': 'Click the button that corresponds to your environment. These buttons determine how long the app will listen for music.',
    'step 3': 'Sing',
    'step3_desc': 'Squeeze your AirPods stem or click the microphone button to begin the song recognition process.',
    'step 4': 'Enjoy Your Music!',
    'step4_desc': 'Once a song is recognized, you can play it directly in your preferred music app.',
    'step 5': 'View Your History',
    'step5_desc': 'Can\'t remember the song you just listened to? View your search history by clicking the clock icon on the main page of Reczt.',
    'got it': 'Got it!',
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
    'by': 'de',
    'User Manual': 'Cómo usar',
    'step 1': 'Paso 1: Configura tus ajustes',
    'step1_desc': 'Selecciona tu plataforma de música y idioma preferidos.',
    'step 2': 'Paso 2: ¿Dónde estás?',
    'step2_desc': 'Haz clic en el botón que corresponde a tu entorno. Estos botones determinan cuánto tiempo escuchará la aplicación música.',
    'step 3': 'Paso 3: ¡Canta!',
    'step3_desc': 'Aprieta el tallo de tus AirPods o haz clic en el botón del micrófono para comenzar el proceso de reconocimiento de canciones.',
    'step 4': 'Paso 4: ¡Disfruta tu música!',
    'step4_desc': 'Una vez que se reconozca una canción, puedes reproducirla directamente en tu aplicación de música preferida.',
    'step 5': 'Paso 5: Ver tu historial',
    'step5_desc': '¿No recuerdas la canción que acabas de escuchar? Puedes ver tu historial de búsqueda haciendo clic en el icono del reloj en la página principal de Reczt.',
    'got it': '¡Entendido!',
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
    'by': 'par',
    'User Manual': 'Comment utiliser',
    'step 1': 'Étape 1 : Configurez vos paramètres',
    'step1_desc': 'Sélectionnez votre plateforme musicale et votre langue préférées.',
    'step 2': 'Étape 2 : Où êtes-vous ?',
    'step2_desc': 'Cliquez sur le bouton correspondant à votre environnement. Ces boutons déterminent combien de temps l\'application écoutera la musique.',
    'step 3': 'Étape 3 : Chantez !',
    'step3_desc': 'Appuyez sur la tige de vos AirPods ou cliquez sur le bouton du microphone pour commencer le processus de reconnaissance de chansons.',
    'step 4': 'Étape 4 : Profitez de votre musique !',
    'step4_desc': 'Une fois qu\'une chanson est reconnue, vous pouvez la lire directement dans votre application musicale préférée.',
    'step 5': 'Étape 5 : Consultez votre historique',
    'step5_desc': 'Vous ne vous souvenez pas de la chanson que vous venez d\'écouter ? Vous pouvez consulter votre historique de recherche en cliquant sur l\'icône de l\'horloge sur la page principale de Reczt.',
    'got it': 'Compris !',
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
    'by': 'von',
    'User Manual': 'Wie man es benutzt',
    'step 1': 'Schritt 1: Konfiguriere deine Einstellungen',
    'step1_desc': 'Wähle deine bevorzugte Musikplattform und Sprache aus.',
    'step 2': 'Schritt 2: Wo bist du?',
    'step2_desc': 'Klicke auf die Schaltfläche, die deiner Umgebung entspricht. Diese Schaltflächen bestimmen, wie lange die App Musik hören wird.',
    'step 3': 'Schritt 3: Singe!',
    'step3_desc': 'Drücke den Stiel deiner AirPods oder klicke auf die Mikrofontaste, um den Song-Erkennungsprozess zu starten.',
    'step 4': 'Schritt 4: Genieße deine Musik!',
    'step4_desc': 'Sobald ein Song erkannt wurde, kannst du ihn direkt in deiner bevorzugten Musik-App abspielen.',
    'step 5': 'Schritt 5: Sieh dir deinen Verlauf an',
    'step5_desc': 'Kannst du dich nicht an den Song erinnern, den du gerade gehört hast? Sieh dir deinen Suchverlauf an, indem du auf das Uhrensymbol auf der Hauptseite von Reczt klickst.',
    'got it': 'Verstanden!',
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
    'by': 'di',
    'User Manual': 'Come usare',
    'step 1': 'Passo 1: Configura le tue impostazioni',
    'step1_desc': 'Seleziona la tua piattaforma musicale e lingua preferita.',
    'step 2': 'Passo 2: Dove ti trovi?',
    'step2_desc': 'Clicca sul pulsante che corrisponde al tuo ambiente. Questi pulsanti determinano per quanto tempo l\'app ascolterà la musica.',
    'step 3': 'Passo 3: Canta!',
    'step3_desc': 'Stringi il gambo dei tuoi AirPods o clicca sul pulsante del microfono per iniziare il processo di riconoscimento della canzone.',
    'step 4': 'Passo 4: Goditi la tua musica!',
    'step4_desc': 'Una volta riconosciuta una canzone, puoi riprodurla direttamente nella tua app musicale preferita.',
    'step 5': 'Passo 5: Visualizza la tua cronologia',
    'step5_desc': 'Non ricordi la canzone che hai appena ascoltato? Visualizza la cronologia delle ricerche cliccando sull\'icona dell\'orologio nella pagina principale di Reczt.',
    'got it': 'Capito!',
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
    'by': 'de',
    'User Manual': 'Como usar',
    'step 1': 'Passo 1: Configure suas preferências',
    'step1_desc': 'Selecione sua plataforma musical e idioma preferido.',
    'step 2': 'Passo 2: Onde você está?',
    'step2_desc': 'Clique no botão que corresponde ao seu ambiente. Esses botões determinam por quanto tempo o app ouvirá a música.',
    'step 3': 'Passo 3: Cante!',
    'step3_desc': 'Segure a alça dos seus AirPods ou clique no botão do microfone para iniciar o processo de reconhecimento da música.',
    'step 4': 'Passo 4: Aproveite sua música!',
    'step4_desc': 'Assim que uma música for reconhecida, você pode reproduzi-la diretamente em seu app musical preferido.',
    'step 5': 'Passo 5: Visualize seu histórico',
    'step5_desc': 'Não se lembra da música que acabou de ouvir? Visualize o histórico de buscas clicando no ícone do relógio na página principal do Reczt.',
    'got it': 'Entendi!',
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
    'by': 'アーティスト:',
    'User Manual': '使い方',
    'step 1': '手順 1: 設定を構成する',
    'step1_desc': 'お好みの音楽プラットフォームと言語を選択してください。',
    'step 2': '手順 2: どこにいますか？',
    'step2_desc': '環境に一致するボタンをクリックしてください。これらのボタンは、アプリが音楽を聞く時間を決定します。',
    'step 3': '手順 3: 歌ってください！',
    'step3_desc': 'AirPodsのハンドルを押すか、マイクボタンをクリックして、曲認識プロセスを開始してください。',
    'step 4': '手順 4: 音楽をお楽しみください！',
    'step4_desc': '曲が認識されると、お好みの音楽アプリで直接再生できます。',
    'step 5': '手順 5: 履歴を表示する',
    'step5_desc': '最近聞いた曲が思い出せませんか？ Recztのメインページで時計アイコンをクリックして検索履歴を表示できます。',
    'got it': '了解しました！',
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
    'by': '아티스트:',
    'User Manual': '사용 방법',
    'step 1': '1단계: 설정 구성',
    'step1_desc': '선호하는 음악 플랫폼과 언어를 선택하세요.',
    'step 2': '2단계: 어디에 계신가요?',
    'step2_desc': '환경에 해당하는 버튼을 클릭하세요. 이 버튼들은 앱이 음악을 듣는 시간을 결정합니다.',
    'step 3': '3단계: 노래 부르기',
    'step3_desc': 'AirPods 스템을 누르거나 마이크 버튼을 클릭하여 노래 인식 프로세스를 시작하세요.',
    'step 4': '4단계: 음악 즐기기!',
    'step4_desc': '노래가 인식되면 선호하는 음악 앱에서 직접 재생할 수 있습니다.',
    'step 5': '5단계: 기록 보기',
    'step5_desc': '방금 들은 노래가 기억나지 않나요? Reczt의 메인 페이지에서 시계 아이콘을 클릭하여 검색 기록을 확인할 수 있습니다.',
    'got it': '알겠습니다!',
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
    'by': '歌手：',
    'User Manual': '使用方法',
    'step 1': '第一步：配置设置',
    'step1_desc': '请选择您偏好的音乐平台和语言。',
    'step 2': '第二步：您在哪里？',
    'step2_desc': '点击与您的环境相对应的按钮。这些按钮将决定应用程序聆听音乐的时间。',
    'step 3': '第三步：唱歌！',
    'step3_desc': '按住您的 AirPods 手柄或点击麦克风按钮以启动歌曲识别过程。',
    'step 4': '第四步：享受您的音乐！',
    'step4_desc': '一旦识别出歌曲，您就可以直接在您偏好的音乐应用中播放它。',
    'step 5': '第五步：查看历史记录',
    'step5_desc': '记不起刚听过的歌曲吗？在 Reczt 的主页面上点击时钟图标来查看搜索历史。',
    'got it': '明白了！',
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
    'by': 'द्वारा',
    'User Manual': 'कैसे उपयोग करें',
    'step 1': 'चरण 1: अपनी सेटिंग्स कॉन्फ़िगर करें',
    'step1_desc': 'अपनी पसंदीदा म्यूजिक प्लेटफ़ॉर्म और भाषा चुनें।',
    'step 2': 'चरण 2: आप कहाँ हैं?',
    'step2_desc': 'अपने वातावरण के अनुसार बटन पर क्लिक करें। ये बटन यह निर्धारित करते हैं कि ऐप कितनी देर तक संगीत सुनेगा।',
    'step 3': 'चरण 3: गाओ!',
    'step3_desc': 'अपने AirPods स्टेम को दबाएं या गाने की पहचान प्रक्रिया शुरू करने के लिए माइक्रोफ़ोन बटन पर क्लिक करें।',
    'step 4': 'चरण 4: अपने संगीत का आनंद लें!',
    'step4_desc': 'एक बार जब कोई गाना पहचाना जाता है, तो आप ইसे सीधे অपनी पसंदीदा म्यूजिक ঐप में চला सकते हैं।',
    'step 5': 'चरण 5: অপনা ইতিহাস দেখেন',
    'step5_desc': 'ক্যা আপকো মনে না হয় কি আপনি এখনই কোনো গানা শুনেছিলেন? Reczt এর প্রধান পৃষ্ঠায় ঘড়ির আইকনের উপরে click করে আপ અપनાર search historyকে view کرতے پারবেن।',
    'got it': 'समझ गया!',
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
    'by': 'исполнитель',
    'User Manual': 'Как использовать',
    'step 1': 'Шаг 1: Настройте параметры',
    'step1_desc': 'Выберите предпочитаемую музыкальную платформу и язык.',
    'step 2': 'Шаг 2: Где вы находитесь?',
    'step2_desc': 'Нажмите кнопку, соответствующую вашей обстановке. Эти кнопки определяют, как долго приложение будет слушать музыку.',
    'step 3': 'Шаг 3: Пойте!',
    'step3_desc': 'Нажмите на стержень ваших AirPods или нажмите кнопку микрофона, чтобы начать процесс распознавания песни.',
    'step 4': 'Шаг 4: Наслаждайтесь музыкой!',
    'step4_desc': 'После распознавания песни вы можете воспроизвести ее напрямую в предпочитаемом музыкальном приложении.',
    'step 5': 'Шаг 5: Просмотр истории',
    'step5_desc': 'Не можете вспомнить песню, которую только что слушали? Просмотрите историю поиска, нажав на значок часов на главной странице Reczt.',
    'got it': 'С понятием!',
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
    'by': 'sanatçı',
    'User Manual': 'Nasıl Kullanılır',
    'step 1': 'Adım 1: Ayarlarınızı Yapılandırın',
    'step1_desc': 'Tercih ettiğiniz müzik platformunu ve dili seçin.',
    'step 2': 'Adım 2: Neredesiniz?',
    'step2_desc': 'Ortamınıza karşılık gelen düğmeye tıklayın. Bu düğmeler, uygulamanın müziği ne kadar süre dinleyeceğini belirler.',
    'step 3': 'Adım 3: Şarkı Söyleyin!',
    'step3_desc': 'AirPods sapını sıkın veya şarkı tanıma sürecini başlatmak için mikrofon düğmesine tıklayın.',
    'step 4': 'Adım 4: Müziğinizin Tadını Çıkarın!',
    'step4_desc': 'Bir şarkı tanındığında, onu tercih ettiğiniz müzik uygulamasında doğrudan çalabilirsiniz.',
    'step 5': 'Adım 5: Geçmişinizi Görüntüleyin',
    'step5_desc': 'Az önce dinlediğiniz şarkıyı hatırlamıyor musunuz? Reczt ana sayfasındaki saat simgesine tıklayarak arama geçmişinizi görüntüleyebilirsiniz.',
    'got it': 'Anladım!',
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
    'by': 'بواسطة',
    'User Manual': 'كيفية الاستخدام',
    'step 1': 'الخطوة 1: تكوين إعداداتك',
    'step1_desc': 'حدد منصة الموسيقى واللغة المفضلة لديك.',
    'step 2': 'الخطوة 2: أين أنت؟',
    'step2_desc': 'انقر على الزر الذي يتوافق مع بيئتك. تحدد هذه الأزرار المدة التي ستستمع فيها التطبيق إلى الموسيقى.',
    'step 3': 'الخطوة 3: غنِ!',
    'step3_desc': 'اضغط على ساق AirPods الخاصة بك أو انقر على زر الميكروفون لبدء عملية التعرف على الأغاني.',
    'step 4': 'الخطوة 4: استمتع بموسيقاك!',
    'step4_desc': 'بمجرد التعرف على أغنية، يمكنك تشغيلها مباشرة في تطبيق الموسيقى المفضل لديك.',
    'step 5': 'الخطوة 5: عرض سجل البحث الخاص بك',
    'step5_desc': 'هل لا تتذكر الأغنية التي استمعت إليها للتو؟ يمكنك عرض سجل البحث الخاص بك بالنقر على أيقونة الساعة في الصفحة الرئيسية لتطبيق Reczt.',
    'got it': 'فهمت!',
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
    'by': 'door',
    'User Manual': 'Hoe te gebruiken',
    'step 1': 'Stap 1: Stel je voorkeuren in',
    'step1_desc': 'Selecteer je favoriete muziekplatform en taal.',
    'step 2': 'Stap 2: Waar ben je?',
    'step2_desc': 'Klik op de knop die overeenkomt met je omgeving. Deze knoppen bepalen hoe lang de app naar muziek zal luisteren.',
    'step 3': 'Stap 3: Zing!',
    'step3_desc': 'Druk op de steel van je AirPods of klik op de microfoonknop om het nummerherkenningsproces te starten.',
    'step 4': 'Stap 4: Geniet van je muziek!',
    'step4_desc': 'Zodra een nummer is herkend, kun je het direct afspelen in je favoriete muziekapp.',
    'step 5': 'Stap 5: Bekijk je geschiedenis',
    'step5_desc': 'Kun je je niet herinneren welk nummer je net hebt gehoord? Je kunt je zoekgeschiedenis bekijken door op het klokpictogram op de startpagina van Reczt te klikken.',
    'got it': 'Verstanden!',
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
    'by': 'wykonawca',
    'User Manual': 'Jak korzystać',
    'step 1': 'Krok 1: Skonfiguruj ustawienia',
    'step1_desc': 'Wybierz preferowaną platformę muzyczną i język.',
    'step 2': 'Krok 2: Gdzie jesteś?',
    'step2_desc': 'Kliknij przycisk odpowiadający Twojemu otoczeniu. Te przyciski określają, jak długo aplikacja będzie słuchać muzyki.',
    'step 3': 'Krok 3: Śpiewaj!',
    'step3_desc': 'Naciśnij trzonek swoich AirPods lub kliknij przycisk mikrofonu, aby rozpocząć proces rozpoznawania utworu.',
    'step 4': 'Krok 4: Ciesz się muzyką!',
    'step4_desc': 'Po rozpoznaniu utworu możesz odtworzyć go bezpośrednio w preferowanej aplikacji muzycznej.',
    'step 5': 'Krok 5: Sprawdź swoją historię',
    'step5_desc': 'Nie pamiętasz, jaką piosenkę właśnie słuchałeś? Możesz sprawdzić historię wyszukiwania, klikając ikonę zegara na stronie głównej Reczt.',
    'got it': 'Zrozumiano!',
  },
};

class MyApp extends StatelessWidget {
  final String currentLang;
  
  const MyApp({super.key, this.currentLang = 'en'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Locale(currentLang), // Replaces _currentLocale
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
    debugPrint("=== DEBUG: Invoking checkSiriTrigger on native channel... ===");
    final dynamic result = await _siriChannel.invokeMethod('checkSiriTrigger');
    debugPrint("=== DEBUG: checkSiriTrigger returned: $result ===");

    if (result == true) {
      debugPrint("=== DEBUG: Siri trigger was TRUE! Starting recorder... ===");
      _isExplicitlyPausedForRecording = true;
      await _silencePlayer.pause();
      await Future.delayed(const Duration(milliseconds: 800));

      if (await _audioRecorder.hasPermission()) {
        if (mounted && !_isRecording) {
          _startRecording();
        }
      }
    } else {
      debugPrint("=== DEBUG: Trigger returned false or null. No recording started. ===");
    }
  } catch (e) {
    debugPrint('=== DEBUG ERROR: $e ===');
  }
}
  // Self-healing retry function to handle Siri microphone handoff
  Future<void> _startRecordingWithRetry() async {
    int attempts = 0;
    bool success = false;

    while (attempts < 3 && !success && mounted) {
      attempts++;
      try {
        debugPrint("Attempting to start recording (Attempt $attempts)...");
        await _startRecording();
        success = true;
        debugPrint("Microphone successfully locked and recording!");
      } catch (e) {
        debugPrint("Attempt $attempts failed (Siri still holding hardware): $e");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!success) {
      _isExplicitlyPausedForRecording = false;
      _initSilencePlayer();
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

bool _isExplicitlyPausedForRecording = false;

Future<void> _initSilencePlayer() async {
  try {
    // 1. Force looping mode
    await _silencePlayer.setReleaseMode(ReleaseMode.loop);
    
    // 2. Set up a self-healing watchdog state listener
    _silencePlayer.onPlayerStateChanged.listen((state) {
      debugPrint("Silence Player State Changed: $state");
      
      // If iOS pauses or stops it, force it back on UNLESS we are in the middle of mic recording
      if ((state == PlayerState.paused || state == PlayerState.stopped) && !_isExplicitlyPausedForRecording) {
        debugPrint("Silence track was interrupted! Auto-restarting loop...");
        _silencePlayer.play(AssetSource('silence.mp3'));
      }
    });

    // 3. Start playback immediately
    await _silencePlayer.play(AssetSource('silence.mp3'));
    debugPrint("Silence track successfully locked in forever-loop!");
  } catch (e) {
    debugPrint("Error initializing silence player: $e");
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
    _isExplicitlyPausedForRecording = false;
_initSilencePlayer(); // Re-engage background audio lock

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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // =========================================================
              // 1. CENTERED TITLE & 3 HORIZONTAL BUTTONS
              // =========================================================
              Text(
                t('app_title'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Button 1: Settings
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.deepPurple),
                    tooltip: t('settings_title'),
                    onPressed: _showPreferencesDialog,
                  ),
                  const SizedBox(width: 16),

                  // Button 2: History
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.deepPurple),
                    tooltip: t('history_title'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryPage(lang: _selectedLanguage),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),

                  // Button 3: User Manual (Book Icon)
                  IconButton(
                    icon: const Icon(Icons.menu_book, color: Colors.deepPurple),
                    tooltip: t('User Manual'),
                    onPressed: () => _showUserManualDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              // =========================================================
              // EXISTING RECORDING & MODE SELECTION UI
              // =========================================================
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

void _showUserManualDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(Icons.menu_book, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(t('User Manual')), // Dynamic translation
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildManualStep(
            step: "1",
            title: t('step 1'), // Dynamic translation
            desc: t('step1_desc'),   // Dynamic translation
          ),
          const Divider(height: 20),
          _buildManualStep(
            step: "2",
            title: t('step 2'), // Dynamic translation
            desc: t('step2_desc'),   // Dynamic translation
          ),
          const Divider(height: 20),
          _buildManualStep(
            step: "3",
            title: t('step 3'), // Dynamic translation
            desc: t('step3_desc'),   // Dynamic translation
          ),
          const Divider(height: 20),
          _buildManualStep(
            step: "4",
            title: t('step 4'), // Dynamic translation
            desc: t('step4_desc'),   // Dynamic translation
          ),
          const Divider(height: 20),
          _buildManualStep(
            step: "5",
            title: t('step 5'), // Dynamic translation
            desc: t('step5_desc'),   // Dynamic translation
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('got it')), // Dynamic translation
        ),
      ],
    ),
  );
}

  Widget _buildManualStep({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Colors.deepPurple,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
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
// ... all your existing main.dart code and classes end here ...

 // <-- Last closing bracket of your _AudioRecorderScreenState class

// PASTE IT HERE (outside any class)
class LanguageMatcher {
  static String normalizeLanguage(String lang) {
    final cleaned = lang.toLowerCase().trim();
    if (cleaned.startsWith('en') || cleaned == 'english') return 'en';
    if (cleaned.startsWith('es') || cleaned == 'spanish') return 'es';
    if (cleaned.startsWith('fr') || cleaned == 'french') return 'fr';
    if (cleaned.startsWith('de') || cleaned == 'german') return 'de';
    if (cleaned.startsWith('ja') || cleaned == 'japanese') return 'ja';
    if (cleaned.startsWith('ko') || cleaned == 'korean') return 'ko';
    return cleaned.length >= 2 ? cleaned.substring(0, 2) : cleaned;
  }

  static bool isLanguageMatch({
    required String userLanguage,
    required String trackLanguage,
    bool allowUnknown = true,
  }) {
    final userCode = normalizeLanguage(userLanguage);
    final trackCode = normalizeLanguage(trackLanguage);
    if (userCode == trackCode) return true;
    if (allowUnknown && (trackCode == 'un' || trackCode == 'zxx' || trackCode.isEmpty)) {
      return true;
    }
    return false;
  }

  static List<T> filterResultsByLanguage<T>({
    required List<T> results,
    required String userLanguage,
    required String Function(T item) getTrackLanguage,
    bool strictMode = false,
  }) {
    final matchedResults = results.where((item) {
      final trackLang = getTrackLanguage(item);
      return isLanguageMatch(
        userLanguage: userLanguage,
        trackLanguage: trackLang,
        allowUnknown: !strictMode,
      );
    }).toList();

    if (matchedResults.isEmpty) {
      return results; // Fallback if no exact match found
    }
    return matchedResults;
  }
}

