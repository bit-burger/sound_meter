import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_neumorphic_sliders.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:ionicons/ionicons.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final Directory applicationDirectory =
    await getApplicationDocumentsDirectory();
    final String path =
        applicationDirectory.path + "/a.aac";
    final File file = File(path);
    if (!file.existsSync()) {
      ByteData bytes = await rootBundle.load("lib/a.aac");
      file.writeAsBytes(bytes.buffer.asInt8List());
      file.create();
    }
    Settings.preferences = await SharedPreferences.getInstance();
    if (Settings.preferences.containsKey("lowValue")) {
      print(Settings.preferences.getDouble("lowValue"));
      print(Settings.preferences.getDouble("highValue"));
      print(Settings.preferences.getDouble("maxValue"));
    } else {
      Settings.preferences.setDouble("lowValue", 0);
      Settings.preferences.setDouble("highValue", 100);
      Settings.preferences.setDouble("maxValue", 80);
    }
  } catch (error) {
    print(error);
  }

  runApp(App());
}

const List<int> colorCodes = [
  0xFFFFADAD,
  0xFFFFC2A9,
  0xFFFFD6A5,
  0xFFFDFFB6,
  0xFFCAFFBF,
  0xFFB3FBDF,
  0xFFAAE0EF,
  0xFFA0C4FF,
  0xFFBDB2FF,
  0xFFEFADFF,
];

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NeumorphicApp(
      theme: NeumorphicThemeData(intensity: 8, depth: 10),
      themeMode: ThemeMode.light,
      home: MyApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRecording = false;
  bool _isPlaying = false;
  NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading> _noiseSubscription;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter(onError);
    startRecording();
  }

  void startRecording() {
    this.lowValue = Settings.preferences.getDouble("lowValue");
    this.highValue = Settings.preferences.getDouble("highValue");
    this.maxValue = Settings.preferences.getDouble("maxValue");
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen(onData);
    } catch (exception) {
      print(exception);
    }
    this._isRecording = true;
  }

  void stopRecording() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription.cancel();
        _noiseSubscription = null;
      }
      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  void onData(NoiseReading data) {
    setState(() {
      this.data = data.meanDecibel;
      if (data.meanDecibel / 1.2 > maxValue && !_isPlaying) {
        _isPlaying = true;
        () async {
          Directory applicationDirectory =
              await getApplicationDocumentsDirectory();
          final String path = applicationDirectory.path + "/a.aac";
          print(path);
          await _noiseSubscription.cancel();
          _noiseSubscription = null;
          _isRecording = false;
          FlutterSoundPlayer()
            ..openAudioSession(withUI: true).then((player) {
              player
                  .startPlayer(
                      fromURI: path,
                      whenFinished: () {
                        player.closeAudioSession().then((player) {
                          _isPlaying = false;
                          this._isRecording = true;
                          startRecording();
                        }).catchError((error) {
                          _isPlaying = false;
                          print(error);
                        });
                      })
                  .catchError((error) {
                _isPlaying = false;
                print(error);
              });
            });
        }();
      }
    });
  }

  double data;

  void onError(PlatformException error) {
    print("**********************");
    print(error.toString());
    print("**********************");
    _isRecording = false;
  }

  Widget colorBox(int color, bool isActivated) => Expanded(
        child: Neumorphic(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.symmetric(vertical: 7.5, horizontal: 15),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250),
            color: isActivated ? Color(color) : NeumorphicColors.background,
          ),
          style: NeumorphicStyle(),
        ),
      );
  double lowValue;
  double highValue;
  double maxValue;
  List<Widget> getContent(double db) {
    final _db = ((db / 1.2) - lowValue) / (highValue - lowValue) * 10;
    print(db.toString() + " -> " + _db.toString());
    final List<Widget> list = List<Widget>.generate(
        10, (i) => colorBox(colorCodes[i], _db > (9 - i).toDouble()));
    list.insert(
        0,
        SizedBox(
          height: 5,
        ));
    list.add(SizedBox(
      height: 5,
    ));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) async {
            if ((details.globalPosition.dy) > 200) {
              if (_noiseSubscription != null) {
                await _noiseSubscription.cancel().then((value) {
                  _noiseSubscription = null;
                  _isRecording = false;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) {
                      return Settings(startRecording);
                    }),
                  );
                }, onError: (error) {
                  print(error.toString());
                });
              } else {
                throw ErrorDescription("noiseSubscription == null");
              }
            }
          },
          child: Container(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7.5),
              child: Column(
                children: getContent(data ?? 0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// class Settings {
//   static SharedPreferences preferences;
// }
//
// class SettingsState {
//   static final double valueUnterschied = 20;
//   static final textColor = Colors.grey[700];
//   static final TextStyle titleStyle = TextStyle(
//     color: SettingsState.textColor,
//     fontSize: 17,
//   );
//   static const EdgeInsets titleInsets =
//       EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8);
// }
class Settings extends StatefulWidget {
  static SharedPreferences preferences;
  final void Function() continueRecording;
  Settings(this.continueRecording);
  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  double lowValue = 0;
  double highValue = 0;
  double maxValue = 0;

  void checkMaxValue() {
    if (maxValue > highValue) {
      maxValue = highValue;
    } else if (maxValue < lowValue) {
      maxValue = lowValue;
    }
  }

  @override
  void dispose() {
    Settings.preferences.setDouble("lowValue", lowValue);
    Settings.preferences.setDouble("highValue", highValue);
    Settings.preferences.setDouble("maxValue", maxValue);
    widget.continueRecording();
    super.dispose();
  }

  @override
  void initState() {
    setState(() {
      lowValue = Settings.preferences.getDouble("lowValue");
      highValue = Settings.preferences.getDouble("highValue");
      maxValue = Settings.preferences.getDouble("maxValue");
    });
    super.initState();
  }

  static final double valueUnterschied = 20;
  static final textColor = Colors.grey[700];
  static final TextStyle titleStyle = TextStyle(
    color: SettingsState.textColor,
    fontSize: 17,
  );
  static const EdgeInsets titleInsets =
      EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomNeumorphicAppBar(
        title: Text("Settings"),
        buttonStyle: NeumorphicStyle(boxShape: NeumorphicBoxShape.circle()),
      ),
      body: Container(
        padding: EdgeInsets.all(25).copyWith(top: 0),
        child: Neumorphic(
          style: NeumorphicStyle(
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(25)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Padding(
                padding: titleInsets,
                child: Text(
                  "Decibel range",
                  style: titleStyle,
                ),
              ),
              CustomNeumorphicRangeSlider(
                valueLow: lowValue,
                valueHigh: highValue,
                max: 100,
                min: 0,
                onChangedLow: (value) {
                  setState(() {
                    if (value <= highValue - valueUnterschied) {
                      lowValue = value;
                    } else {
                      lowValue = highValue - valueUnterschied;
                    }
                    checkMaxValue();
                  });
                },
                onChangeHigh: (value) {
                  setState(() {
                    if (value >= lowValue + valueUnterschied) {
                      highValue = value;
                    } else {
                      highValue = lowValue + valueUnterschied;
                    }
                    checkMaxValue();
                  });
                },
              ),
              Padding(
                padding: titleInsets,
                child: Text(
                  "When to play the sound",
                  style: titleStyle,
                ),
              ),
              CustomNeumorphicSlider(
                value: maxValue,
                max: 100,
                min: 0,
                maxValue: highValue,
                minValue: lowValue,
                onChanged: (value) {
                  setState(() {
                    maxValue = value;
                    checkMaxValue();
                  });
                },
              ),
              Padding(
                padding: titleInsets,
                child: Text(
                  "Custom sound",
                  style: titleStyle,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5),
                child: AudioRecordPlayer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Fn = void Function();

class AudioRecordPlayer extends StatefulWidget {
  @override
  _AudioRecordPlayerState createState() => _AudioRecordPlayerState();
}

class _AudioRecordPlayerState extends State<AudioRecordPlayer>
    with TickerProviderStateMixin {
  FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  bool _mplaybackReady = false;
  String _mPath;

  @override
  void initState() {
    _mPlayer.openAudioSession().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });
    openTheRecorder().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });

    super.initState();
  }

  @override
  void dispose() async {
    stopPlayer();
    _mPlayer.closeAudioSession();
    _mPlayer = null;

    if(!_mRecorder.isStopped) stopRecorder();
    _mRecorder.closeAudioSession();
    _mRecorder = null;
    if (_mPath != null) {
      var outputFile = File(_mPath);
      if (outputFile.existsSync()) {
        outputFile.delete();
      }
    }
    super.dispose();
    await _stopWatchTimer.dispose();
  }

  Future<void> openTheRecorder() async {
    var tempDir = await getTemporaryDirectory();
    _mPath = '${tempDir.path}/flutter_sound_example.aac';
    var outputFile = File(_mPath);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    await _mRecorder.openAudioSession();
    _mRecorderIsInited = true;
  }

  Future<void> record() async {
    assert(_mRecorderIsInited && _mPlayer.isStopped);
    await _mRecorder.startRecorder(
      toFile: _mPath,
      codec: Codec.aacADTS,
    );
    _stopWatchTimer.onExecute.add(StopWatchExecute.reset);
    _stopWatchTimer.onExecute.add(StopWatchExecute.start);
    setState(() {});
  }

  Future<void> stopRecorder() async {
    await _mRecorder.stopRecorder();
    _stopWatchTimer.onExecute.add(StopWatchExecute.stop);
    _mplaybackReady = true;
  }

  void play() async {
    assert(_mPlayerIsInited &&
        _mplaybackReady &&
        _mRecorder.isStopped &&
        _mPlayer.isStopped);
    await _mPlayer.startPlayer(
        fromURI: _mPath,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {});
        });
    setState(() {});
  }

  Future<void> stopPlayer() async {
    await _mPlayer.stopPlayer();
  }

  _Fn getRecorderFn() {
    if (!_mRecorderIsInited || !_mPlayer.isStopped) {
      return null;
    }
    return _mRecorder.isStopped
        ? record
        : () {
            stopRecorder().then((value) => setState(() {}));
          };
  }

  _Fn getPlaybackFn() {
    if (!_mPlayerIsInited || !_mplaybackReady || !_mRecorder.isStopped) {
      return null;
    }
    return _mPlayer.isStopped
        ? play
        : () {
            stopPlayer().then((value) => setState(() {}));
          };
  }

  Future<void> beginRecording() async {
    final f = getRecorderFn();
    if (f != null) f();
  }

  static const NeumorphicStyle roundStyle = NeumorphicStyle(
    boxShape: NeumorphicBoxShape.circle(),
  );

  static const double iconSize = 40;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Neumorphic(
        style: NeumorphicStyle(
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(25)),
            depth: -NeumorphicTheme.currentTheme(context).depth),
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    NeumorphicButton(
                      child: Icon(
                        Ionicons.mic_outline,
                        size: iconSize,
                        color: _mRecorder.isRecording
                            ? Color(colorCodes.first)
                            : SettingsState.textColor,
                      ),
                      padding: EdgeInsets.all(7.5),
                      onPressed: () {
                        var f = getRecorderFn();
                        if (f != null) f();
                      },
                      style: roundStyle.copyWith(
                          depth: (!_mPlayer.isStopped ||
                                  !_mRecorderIsInited ||
                                  !_mPlayer.isStopped)
                              ? 1
                              : null),
                      curve: Curves.easeOutCubic,
                      duration: Duration(milliseconds: 250),
                    ),
                    NeumorphicButton(
                      child: Icon(
                        Ionicons.headset_outline,
                        size: iconSize,
                        color: _mPlayer.isPlaying
                            ? Color(colorCodes[8])
                            : SettingsState.textColor,
                      ),
                      padding: EdgeInsets.all(7.5),
                      onPressed: () {
                        var f = getPlaybackFn();
                        if (f != null) f();
                      },
                      style: roundStyle.copyWith(
                          depth: (!_mPlayerIsInited ||
                                  !_mplaybackReady ||
                                  !_mRecorder.isStopped)
                              ? 1
                              : null),
                      curve: Curves.easeOutCubic,
                      duration: Duration(milliseconds: 250),
                    ),
                    NeumorphicButton(
                      child: Icon(
                        Ionicons.save_outline,
                        size: iconSize,
                        color: SettingsState.textColor,
                      ),
                      padding: EdgeInsets.all(7.5),
                      onPressed: ([bool bool]) {
                        if (_mRecorder.isRecording) return;
                        final file = File(_mPath);
                        if (!file.existsSync())
                          throw ErrorDescription(
                              "FILE DOESNT EXIST THAT WANTS TO BE SAVED");
                        () async {
                          final Directory applicationDirectory =
                              await getApplicationDocumentsDirectory();
                          final String path =
                              applicationDirectory.path + "/a.aac";
                          if (File(path).existsSync()) File(path).delete();
                          file.copy(path).then((value) =>
                              print(value.path));
                        }();
                      },
                      style: roundStyle.copyWith(
                          depth: (!_mplaybackReady || _mRecorder.isRecording)
                              ? 1
                              : null),
                      curve: Curves.easeOutCubic,
                      duration: Duration(milliseconds: 250),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

