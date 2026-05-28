# VocabApp

A personal iOS app for building English vocabulary and practicing listening. Add words manually or search for them by name, study with flashcards, and train your ear with a listening practice mode — all powered by Google WaveNet TTS (with AVSpeechSynthesizer as a fallback).

## Features

### Word Management
- Add words manually (word, Korean meaning, example sentence)
- Search a word by name to auto-fill rich details via the **Anthropic Claude API**: pronunciation, part of speech, detailed English definition, example sentences, nuance tips, and related words
- Browse and filter your word list; tap any entry to view its full detail card

### Set Management
- Words are automatically grouped into **sets of 20**
- View all sets and track how many words each set contains
- A set is marked "pending" until it reaches 20 words

### Flashcards
- Flip cards to reveal the Korean meaning and example sentence
- Swipe through a set or shuffle for randomized review

### Listening Practice
- Listen to words and type what you hear
- Adjustable playback speed (normal / slow)
- Session history records your answers and scores

### Text-to-Speech
- **Primary**: Google Cloud WaveNet TTS (`en-US-Wavenet-D`) at a natural speaking rate
- **Fallback**: `AVSpeechSynthesizer` when the Google TTS key is not configured
- Both normal-speed and slow playback are supported

### Settings
- Store the **Anthropic API key** and **Google Cloud TTS API key** securely in the iOS Keychain
- Keys are never written to disk in plain text

## Requirements

| Requirement | Version |
|---|---|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |

**API Keys (stored in app Settings):**
- **Anthropic API key** — required for word search / auto-fill
- **Google Cloud TTS API key** — optional; enables WaveNet voices (falls back to AVSpeech if absent)

## Getting Started

1. Clone the repo and open `VocabApp.xcodeproj` in Xcode.
2. Select your target device or simulator (iOS 17+).
3. Build and run (`⌘R`).
4. Open **Settings** inside the app and paste your API keys.

## Screenshots

<!-- Add screenshots here -->
