import 'dart:io';
import 'dart:convert';

void main() {
  // 1. Load your base file
  // Make sure this path points to the JSON file you uploaded
  final file = File('assets/animations/workout_hero.json');
  if (!file.existsSync()) {
    print('Error: Base JSON file not found at ${file.path}');
    return;
  }

  final data = jsonDecode(file.readAsStringSync());

  // 2. The "Freeze" Function: Turns the walking character into a static mannequin
  void freezeAllLayers(List layers) {
    for (var layer in layers) {
      if (layer['ks'] != null) {
        final ks = layer['ks'];
        // Loop through Position, Rotation, Scale, Opacity, Anchor
        for (var prop in ['p', 'r', 's', 'o', 'a']) {
          if (ks[prop] != null && ks[prop]['a'] == 1) {
            // Extract the starting value from the first keyframe
            var startVal = ks[prop]['k'][0]['s'];

            // Lottie requires single values (not arrays) for static rotation/opacity
            if (startVal is List && startVal.length == 1 && prop != 'p' && prop != 's' && prop != 'a') {
              startVal = startVal[0];
            }
            // Overwrite the animation array with a static value
            ks[prop] = {'a': 0, 'k': startVal};
          }
        }
      }
      // Recursively freeze nested pre-compositions
      if (layer['layers'] != null) freezeAllLayers(layer['layers']);
    }
  }

  // 3. The "Shrug" Injector: Adds precise vertical movement to the forearms
  void injectShrug(List layers) {
    for (var layer in layers) {
      // Left Arm Shrug
      if (layer['nm'] == 'Cẳng tay trái Outlines') {
        layer['ks']['p'] = {
          "a": 1, // 1 means animated
          "k": [
            {"t": 0, "s": [106.887, 96.994, 0], "to": [0, -30, 0], "ti": [0, 0, 0]},
            {"t": 15, "s": [106.887, 66.994, 0], "to": [0, 30, 0], "ti": [0, 0, 0]},
            {"t": 31, "s": [106.887, 96.994, 0]}
          ]
        };
      }
      // Right Arm Shrug
      if (layer['nm'] == 'Cẳng tay phải Outlines') {
        layer['ks']['p'] = {
          "a": 1,
          "k": [
            {"t": 0, "s": [-4.451, 96.994, 0], "to": [0, -30, 0], "ti": [0, 0, 0]},
            {"t": 15, "s": [-4.451, 66.994, 0], "to": [0, 30, 0], "ti": [0, 0, 0]},
            {"t": 31, "s": [-4.451, 96.994, 0]}
          ]
        };
      }

      // Hide the leftover weights floating near the body
      if (layer['nm'] == 'Shape Layer 10') {
        layer['hd'] = true;
      }

      if (layer['layers'] != null) injectShrug(layer['layers']);
    }
  }

  // Apply the Freeze and Inject functions to the main scene and all assets
  if (data['layers'] != null) freezeAllLayers(data['layers']);
  if (data['assets'] != null) {
    for (var asset in data['assets']) {
      if (asset['layers'] != null) freezeAllLayers(asset['layers']);
    }
  }

  if (data['layers'] != null) injectShrug(data['layers']);
  if (data['assets'] != null) {
    for (var asset in data['assets']) {
      if (asset['layers'] != null) injectShrug(asset['layers']);
    }
  }

  // 4. Save the finalized Shrug file
  final outFile = File('assets/animations/shrug.json');
  outFile.writeAsStringSync(jsonEncode(data));
  print('✅ shrug.json generated successfully!');
}