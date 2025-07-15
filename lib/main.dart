import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'models/flashcard.dart';
import 'models/flashcard_set.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'services/backend_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ujsmgrtrwuyityzfjnkk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqc21ncnRyd3V5aXR5emZqbmtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI1OTY3MzksImV4cCI6MjA2ODE3MjczOX0.sa3SDHo0fQ5kLH18_A5WiXjCVPr-3v3JEJ_R3uN66wI',
  );
  
  // Check if backend server is available
  try {
    await BackendService.checkAvailability();
    print('Backend server availability: ${BackendService.isAvailable}');
  } catch (e) {
    print('Warning: Could not check backend server availability: $e');
  }
  
  await Hive.initFlutter();
  Hive.registerAdapter(FlashcardAdapter());
  Hive.registerAdapter(FlashcardSetAdapter());
  await Hive.openBox<FlashcardSet>('flashcardSets');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flashcards',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purpleAccent),
      ),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return AuthScreen();
    } else {
      return MyHomePage(title: 'UbiFlashcards');
    }
  }
}

class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String _error = '';
  bool _loading = false;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      } else {
        await Supabase.instance.client.auth.signUp(email: email, password: password);
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Sign In' : 'Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error, style: const TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isLogin ? 'Sign In' : 'Sign Up'),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late Box<FlashcardSet> _flashcardSetBox;
  List<FlashcardSet> _flashcardSets = [];
  int _currentSetIndex = 0;
  int _currentIndex = 0;
  bool _showAnswer = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _randomOrder = false;
  List<int> _shuffledIndices = [];
  Set<int> _seenIndices = {};
  String _errorMessage = '';
  DateTime? _errorTimestamp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _flashcardSetBox = Hive.box<FlashcardSet>('flashcardSets');
    if (_flashcardSetBox.isEmpty) {
      // Add initial data if box is empty
      _flashcardSetBox.addAll([
        FlashcardSet(
          name: 'General Knowledge',
          cards: [
            Flashcard(question: 'What is the capital of France?', answer: 'Paris'),
            Flashcard(question: 'What is 2 + 2?', answer: '4'),
            Flashcard(question: 'What is the largest planet?', answer: 'Jupiter'),
          ],
        ),
        FlashcardSet(
          name: 'Science',
          cards: [
            Flashcard(question: 'What is H2O?', answer: 'Water'),
            Flashcard(question: 'What planet is known as the Red Planet?', answer: 'Mars'),
          ],
        ),
      ]);
    }
    _flashcardSets = _flashcardSetBox.values.toList();
  }

  Future<void> _refreshSets({bool selectLast = false}) async {
    setState(() {
      _flashcardSets = _flashcardSetBox.values.toList();
      if (selectLast && _flashcardSets.isNotEmpty) {
        _currentSetIndex = _flashcardSets.length - 1;
        _currentIndex = 0;
        _showAnswer = false;
        _controller.reset();
      }
    });
  }

  void _shuffleCards() {
    final count = _flashcardSets[_currentSetIndex].cards.length;
    _shuffledIndices = List.generate(count, (i) => i)..shuffle();
    _currentIndex = 0;
    _seenIndices.clear();
  }

  void _onSetChanged(int newIndex) {
    setState(() {
      _currentSetIndex = newIndex;
      _currentIndex = 0;
      _showAnswer = false;
      _controller.reset();
      if (_randomOrder) {
        _shuffleCards();
      } else {
        _shuffledIndices.clear();
        _seenIndices.clear();
      }
    });
  }

  void _onRandomOrderChanged(bool value) {
    setState(() {
      _randomOrder = value;
      if (_randomOrder) {
        _shuffleCards();
      } else {
        _shuffledIndices.clear();
        _seenIndices.clear();
        _currentIndex = 0;
      }
      _showAnswer = false;
      _controller.reset();
    });
  }

  void _flipCard() {
    if (_showAnswer) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _nextCard() {
    setState(() {
      if (_randomOrder) {
        _seenIndices.add(_shuffledIndices[_currentIndex]);
        if (_currentIndex < _shuffledIndices.length - 1) {
          _currentIndex++;
        }
        _showAnswer = false;
        _controller.reset();
      } else {
        final cards = _flashcardSets[_currentSetIndex].cards;
        _currentIndex = (_currentIndex + 1) % cards.length;
        _showAnswer = false;
        _controller.reset();
      }
    });
  }

  void _previousCard() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
        _showAnswer = false;
        _controller.reset();
      }
    });
  }

  void _restartCards() {
    setState(() {
      if (_randomOrder) {
        _shuffleCards();
      } else {
        _currentIndex = 0;
      }
      _showAnswer = false;
      _controller.reset();
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _errorTimestamp = DateTime.now();
    });
    
    // Auto-hide error after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _errorTimestamp != null) {
        final timeDiff = DateTime.now().difference(_errorTimestamp!);
        if (timeDiff.inSeconds >= 10) {
          _clearError();
        }
      }
    });
  }

  void _clearError() {
    setState(() {
      _errorMessage = '';
      _errorTimestamp = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSet = _flashcardSets[_currentSetIndex];
    final int displayIndex = _randomOrder && _shuffledIndices.isNotEmpty
        ? _shuffledIndices[_currentIndex]
        : _currentIndex;
    final flashcard = currentSet.cards[displayIndex];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'User Info',
            onPressed: () async {
              final user = Supabase.instance.client.auth.currentUser;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('User Info'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${user?.email ?? "Unknown"}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align tops
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Image.asset(
                    'assets/images/ubiflash_logo.png',
                    width: 60,
                    height: 60,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      DropdownButton<int>(
                        value: _currentSetIndex,
                        items: List.generate(_flashcardSets.length, (index) {
                          return DropdownMenuItem(
                            value: index,
                            child: Text(_flashcardSets[index].name),
                          );
                        }),
                        onChanged: (int? newIndex) {
                          if (newIndex != null) {
                            _onSetChanged(newIndex);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Set',
                        onPressed: _flashcardSets.isEmpty
                            ? null
                            : () async {
                                await showDialog(
                                  context: context,
                                  builder: (context) => _EditSetDialog(
                                    initialSet: _flashcardSets[_currentSetIndex],
                                    onSave: (FlashcardSet updatedSet) async {
                                      final key = _flashcardSetBox.keyAt(_currentSetIndex);
                                      await _flashcardSetBox.put(key, updatedSet);
                                      await _refreshSets();
                                    },
                                  ),
                                );
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'New Set',
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => _EditSetDialog(
                              initialSet: FlashcardSet(name: '', cards: [Flashcard(question: '', answer: '')]),
                              onSave: (FlashcardSet newSet) async {
                                await _flashcardSetBox.add(newSet);
                                await _refreshSets(selectLast: true);
                              },
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.smart_toy),
                        tooltip: 'Generate AI Flashcards',
                        onPressed: () async {
                          // Check if backend is available
                          final isAvailable = await BackendService.checkAvailability();
                          if (!isAvailable) {
                            _showError('Backend server is not available. Please make sure the flashcard_backend server is running on 127.0.0.1:5000');
                            return;
                          }
                          
                          await showDialog(
                            context: context,
                            builder: (context) => _AIGenerateDialog(
                              onGenerate: (FlashcardSet newSet) async {
                                await _flashcardSetBox.add(newSet);
                                await _refreshSets(selectLast: true);
                              },
                              onError: _showError,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Debug Info',
                        onPressed: () async {
                          final serverStatus = await BackendService.getServerStatus();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Debug Information'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Backend Available: ${BackendService.isAvailable}'),
                                  const SizedBox(height: 8),
                                  Text('Backend URL: ${BackendService.baseUrl}'),
                                  const SizedBox(height: 8),
                                  Text('Server Status: ${serverStatus['available'] ?? 'Unknown'}'),
                                  if (serverStatus['error'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Error: ${serverStatus['error']}', style: const TextStyle(color: Colors.red)),
                                  ],
                                  const SizedBox(height: 8),
                                  Text('Flashcard Sets: ${_flashcardSets.length}'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await BackendService.checkAvailability();
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Backend status refreshed: ${BackendService.isAvailable}')),
                                    );
                                  },
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file),
                        tooltip: 'Import Set from CSV',
                        onPressed: () async {
                          String? setName = '';
                          List<Flashcard> importedCards = [];
                          await showDialog(
                            context: context,
                            builder: (context) {
                              final nameController = TextEditingController();
                              return AlertDialog(
                                title: const Text('Import Flashcard Set from CSV'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(labelText: 'Set Name'),
                                      onChanged: (value) => setName = value,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.file_open),
                                      label: const Text('Select CSV File'),
                                      onPressed: () async {
                                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: ['csv'],
                                          withData: kIsWeb, // Ensures bytes are loaded for web
                                        );
                                        if (result != null) {
                                          String csvString;
                                          String? fileName = result.files.single.name;
                                          if (kIsWeb) {
                                            final bytes = result.files.single.bytes;
                                            if (bytes != null) {
                                              csvString = utf8.decode(bytes);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to read file bytes.')),
                                              );
                                              return;
                                            }
                                          } else {
                                            final path = result.files.single.path;
                                            if (path != null) {
                                              csvString = await File(path).readAsString();
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to read file path.')),
                                              );
                                              return;
                                            }
                                          }
                                          // Auto-set Set Name from filename
                                          if (fileName != null && fileName.isNotEmpty) {
                                            String baseName = fileName.replaceAll('.csv', '').replaceAll('_', ' ');
                                            String englishName = baseName.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
                                            nameController.text = englishName;
                                            setName = englishName;
                                          }
                                          final csvRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(csvString);
                                          importedCards = csvRows
                                              .where((row) => row.length >= 2)
                                              .map((row) => Flashcard(question: row[0].toString().trim(), answer: row[1].toString().trim()))
                                              .toList();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Loaded  {importedCards.length} cards from CSV.')),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if ((setName ?? '').trim().isNotEmpty && importedCards.isNotEmpty) {
                                        await _flashcardSetBox.add(FlashcardSet(name: (setName ?? '').trim(), cards: importedCards));
                                        await _refreshSets(selectLast: true);
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: const Text('Import'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete Set',
                        onPressed: _flashcardSets.isEmpty
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Set'),
                                    content: Text('Are you sure you want to delete "${_flashcardSets[_currentSetIndex].name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final key = _flashcardSetBox.keyAt(_currentSetIndex);
                                  await _flashcardSetBox.delete(key);
                                  await _refreshSets();
                                  setState(() {
                                    if (_flashcardSets.isEmpty) {
                                      _currentSetIndex = 0;
                                    } else if (_currentSetIndex >= _flashcardSets.length) {
                                      _currentSetIndex = _flashcardSets.length - 1;
                                    }
                                    _currentIndex = 0;
                                    _showAnswer = false;
                                    _controller.reset();
                                  });
                                }
                              },
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          Checkbox(
                            value: _randomOrder,
                            onChanged: (val) => _onRandomOrderChanged(val ?? false),
                          ),
                          const Text('Random order'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Center flashcard and navigation controls in the window
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentSet.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Builder(
                          builder: (context) {
                            final total = currentSet.cards.length;
                            final int cardNumber = _randomOrder && _shuffledIndices.isNotEmpty
                                ? _currentIndex + 1
                                : _currentIndex + 1;
                            return Text(
                              'Card $cardNumber of $total',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final isUnder = (_animation.value > 0.5);
                          final displayText = isUnder
                              ? flashcard.answer
                              : flashcard.question;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(pi * _animation.value),
                            child: isUnder
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(pi),
                                    child: Card(
                                      elevation: 8,
                                      color: Colors.white,
                                      child: SizedBox(
                                        width: 360, // Increased width
                                        height: 260, // Increased height
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              displayText,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Card(
                                    elevation: 8,
                                    color: Colors.white,
                                    child: SizedBox(
                                      width: 360, // Increased width
                                      height: 260, // Increased height
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            displayText,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _currentIndex > 0 ? _previousCard : null,
                          child: const Text('Previous'),
                        ),
                        const SizedBox(width: 16),
                        Builder(
                          builder: (context) {
                            final total = _flashcardSets[_currentSetIndex].cards.length;
                            final int cardNumber = _currentIndex + 1;
                            final bool isLastCard = cardNumber == total;
                            if (isLastCard) {
                              return ElevatedButton(
                                onPressed: _restartCards,
                                child: const Text('Start Over'),
                              );
                            } else {
                              return ElevatedButton(
                                onPressed: _nextCard,
                                child: const Text('Next'),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    // Error display below the bottom controls
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red.shade600, size: 18),
                              onPressed: _clearError,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Flashcard Set Editor Dialog
class _EditSetDialog extends StatefulWidget {
  final FlashcardSet initialSet;
  final void Function(FlashcardSet) onSave;
  const _EditSetDialog({required this.initialSet, required this.onSave});

  @override
  State<_EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<_EditSetDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _setName;
  late List<Flashcard> _cards;

  @override
  void initState() {
    super.initState();
    _setName = widget.initialSet.name;
    _cards = widget.initialSet.cards.map((c) => Flashcard(question: c.question, answer: c.answer)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Flashcard Set'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Set Name'),
                initialValue: _setName,
                validator: (value) => (value == null || value.isEmpty) ? 'Enter a name' : null,
                onChanged: (value) => setState(() => _setName = value),
              ),
              const SizedBox(height: 16),
              ..._cards.asMap().entries.map((entry) {
                final i = entry.key;
                final card = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Question ${i + 1}'),
                          initialValue: card.question,
                          validator: (value) => (value == null || value.isEmpty) ? 'Enter a question' : null,
                          onChanged: (value) => setState(() => _cards[i] = Flashcard(question: value, answer: card.answer)),
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Answer ${i + 1}'),
                          initialValue: card.answer,
                          validator: (value) => (value == null || value.isEmpty) ? 'Enter an answer' : null,
                          onChanged: (value) => setState(() => _cards[i] = Flashcard(question: card.question, answer: value)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_cards.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete Card',
                                onPressed: () => setState(() => _cards.removeAt(i)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Card'),
                    onPressed: () => setState(() => _cards.add(Flashcard(question: '', answer: ''))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(FlashcardSet(
                name: _setName,
                cards: _cards
                    .where((c) => c.question.trim().isNotEmpty && c.answer.trim().isNotEmpty)
                    .toList(),
              ));
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// AI Generate Dialog
class _AIGenerateDialog extends StatefulWidget {
  final void Function(FlashcardSet) onGenerate;
  final void Function(String) onError;
  const _AIGenerateDialog({required this.onGenerate, required this.onError});

  @override
  State<_AIGenerateDialog> createState() => _AIGenerateDialogState();
}

class _AIGenerateDialogState extends State<_AIGenerateDialog> {
  final _topicController = TextEditingController();
  final _nameController = TextEditingController();
  final _countController = TextEditingController(text: '10');
  bool _isGenerating = false;
  String _errorMessage = '';

  void _updateSetName() {
    final topic = _topicController.text.trim();
    if (topic.isNotEmpty) {
      _nameController.text = BackendService.generateSetName(topic);
    }
  }

  Future<void> _generateFlashcards() async {
    final topic = _topicController.text.trim();
    final setName = _nameController.text.trim();
    final countText = _countController.text.trim();

    if (topic.isEmpty) {
      setState(() => _errorMessage = 'Please enter a topic');
      return;
    }

    if (setName.isEmpty) {
      setState(() => _errorMessage = 'Please enter a set name');
      return;
    }

    final count = int.tryParse(countText) ?? 10;
    if (count < 1 || count > 50) {
      setState(() => _errorMessage = 'Please enter a number between 1 and 50');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = '';
    });

    try {
      final flashcards = await BackendService.generateFlashcards(topic, count: count);
      
      if (flashcards.isEmpty) {
        widget.onError('No flashcards were generated. Please try again.');
        Navigator.of(context).pop();
        return;
      }

      final flashcardSet = FlashcardSet(name: setName, cards: flashcards);
      widget.onGenerate(flashcardSet);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${flashcards.length} flashcards for "$setName"')),
        );
      }
    } catch (e) {
      widget.onError('Failed to generate flashcards: ${e.toString()}');
      Navigator.of(context).pop();
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate AI Flashcards'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'e.g., World War II, Python Programming, Spanish Verbs',
              ),
              onChanged: (_) => _updateSetName(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Set Name',
                hintText: 'Name for your flashcard set',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countController,
              decoration: const InputDecoration(
                labelText: 'Number of Cards',
                hintText: '1-50',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : _generateFlashcards,
          child: _isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate'),
        ),
      ],
    );
  }
}
