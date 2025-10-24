# Instagram Stories Clone

An iOS app demonstrating Instagram-style stories with camera, reactions, and state persistence.

**Disclaimer:** This app is mostly vibe-coded – my focus was on the UX to make this social app with fake users feel less lonely and exciting.

## Demo

### Screenshots

<p align="center">
  <img src="demo/login screen.jpg" width="200" alt="Login Screen"/>
  <img src="demo/story_list.jpg" width="200" alt="Story List"/>
  <img src="demo/story_view_swiping_horizontally_animated.jpg" width="200" alt="Horizontal Swiping"/>
</p>

<p align="center">
  <img src="demo/reacting.jpg" width="200" alt="Reactions"/>
  <img src="demo/story_view_swiping_down.jpg" width="200" alt="Swipe Down to Dismiss"/>
</p>

Special emphasis was put on micro-animations and gestures:
- Floating bubbles in the story list view
- Bubbles moving around when new content is posted
- Micro-animation on heart touch, triggering emoji shower reactions
- 3D rotation transitions when swiping between users
- Intuitive story dismissal by swiping down

## Features

**Story Viewing**
- Story list with visual seen/unseen indicators (gradient vs. gray rings)
- Full-screen viewer with auto-advance timer
- Instagram-style gestures (tap left/right, swipe down, long-press to pause)
- Horizontal scroll between users with 3D transitions *(the tough one!)*
- Viewer count and list *(view count is faked)*

**Interactions**
- 6 reaction types (❤️ 😂 😮 😢 😡 👍) with animated feedback
- Reply input bar *(faked & lacking a visual response)*
- Haptic feedback throughout (login, pull-to-refresh, and more)

**Creation**
- AVFoundation camera with front/back switching
- 6 simple image filters
- Caption support
- Moveable text elements

**State Management**
- Per-story, per-user viewed tracking
- Persistent state across app restarts (UserDefaults)
- Resume from first unviewed story
- Pull-to-refresh for new content

**Performance**
- Aggressive image preloading (5-7 stories ahead)
- Priority-based loading queue
- Image cache to make things smooth

## Tech Stack

- Swift 5.9+, SwiftUI, iOS 17.0+
- AVFoundation (camera), Core Image (filters)
- No external dependencies

## Trade-offs

**Not Implemented**
- Backend API (using mock data)
- Actual view count tracking
- Upload from device photo library (camera preferred)
- Unit/UI tests (would add in production)
- Comprehensive error handling UI
- Proper network & error management

A lot of shortcuts were taken – for example, the Stories data structure remembers which users viewed each story, which isn't scalable - at all.
