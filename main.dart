import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('favoritesBox');

  runApp(const PostReaderApp());
}

class PostReaderApp extends StatelessWidget {
  const PostReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Post Reader & Favorites',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PostsScreen(),
        '/details': (context) => const PostDetailsScreen(),
        '/favorites': (context) => const FavoritesScreen(),
      },
    );
  }
}

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
      );

      if (response.statusCode == 200) {
        setState(() {
          posts = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load posts. Status code: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }

  void _showAddPostDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Body'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final body = bodyController.text.trim();

                if (title.isEmpty || body.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Title and Body cannot be empty!')),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  final response = await http.post(
                    Uri.parse('https://jsonplaceholder.typicode.com/posts'),
                    headers: {
                      'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: jsonEncode({
                      'title': title,
                      'body': body,
                      'userId': 1,
                    }),
                  );

                  if (!mounted) return;

                  if (response.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Post successfully created! (201)')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Failed to create post. Code: ${response.statusCode}')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending POST request: $e')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'View Favorites',
            onPressed: () {
              Navigator.pushNamed(context, '/favorites');
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 20),
                      child: ListTile(
                        title: Text(
                          post['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          post['body'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/details',
                            arguments: {
                              'id': post['id'],
                              'title': post['title'],
                              'body': post['body'],
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPostDialog,
        tooltip: 'Add Post',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PostDetailsScreen extends StatelessWidget {
  const PostDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final int postId = args['id'];
    final String postTitle = args['title'];
    final String postBody = args['body'];

    final box = Hive.box('favoritesBox');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              postTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              postBody,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Save to Favorites'),
                onPressed: () {
                  box.put(postId, {
                    'id': postId,
                    'title': postTitle,
                    'body': postBody,
                    'note': '',
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Saved to favorites successfully!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final box = Hive.box('favoritesBox');

  void _editNote(dynamic key, Map postMap) {
    final noteController = TextEditingController(text: postMap['note'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Personal Note'),
          content: TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: 'Personal Note'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                postMap['note'] = noteController.text.trim();
                box.put(key, postMap);
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note updated!')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedPostsKeys = box.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Posts'),
      ),
      body: savedPostsKeys.isEmpty
          ? const Center(
              child: Text(
                'No favorite posts saved yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: savedPostsKeys.length,
              itemBuilder: (context, index) {
                final key = savedPostsKeys[index];
                final postMap = Map<String, dynamic>.from(box.get(key));

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                      postMap['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(postMap['body'],
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (postMap['note'] != null &&
                            postMap['note'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Note: ${postMap['note']}',
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.amber),
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editNote(key, postMap),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            box.delete(key);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Removed from favorites')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
