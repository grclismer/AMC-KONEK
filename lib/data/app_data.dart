// -----------------------------------------------------------------------------
// APP DATA
// -----------------------------------------------------------------------------

const List<Map<String, String>> stories = [
  {'username': 'You', 'imageUrl': 'assets/me.jpg', 'userId': 'me'},
  {
    'username': 'Kap Onin',
    'imageUrl': 'https://assets.epuzzle.info/puzzle/158/484/original.jpg',
    'userId': 'kap_onin_uid'
  },
  {
    'username': 'Doc. Ron',
    'imageUrl':
        'https://i.audiomack.com/markerenzreyes8/ba5a0a2d03.webp?width=1000&height=1000',
    'userId': 'doc_ron_uid'
  },
];

final List<Map<String, dynamic>> posts = [
  {
    "type": "text",
    "username": "Doc. Ron",
    "avatarUrl":
        "https://i.audiomack.com/markerenzreyes8/ba5a0a2d03.webp?width=1000&height=1000",
    "content": "Triple B!",
    "timestamp": "2h ago",
    "likes": 124,
    "comments": 3,
    "replies": ["Badi!", "Bona.", "80"]
  },
  {
    "type": "image",
    "username": "Arman Salon",
    "avatarUrl":
        "https://m.media-amazon.com/images/M/MV5BMTRkMzcyNDYtYWQzMC00MTU5LTkyYmMtMzA2ODg0YjMzY2Q5XkEyXkFqcGc@._V1_QL75_UY281_CR155,0,190,281_.jpg",
    "content":
        "https://images.gmanews.tv/webpics/2024/11/arman_salon_2024_11_17_12_54_04.jpg",
    "caption": "Two sides of me tuwing tag ulan?",
    "timestamp": "4h ago",
    "likes": 850,
    "comments": 2,
    "replies": ["Mimaaaaah!", "Maaa!"]
  },
  {
    "type": "tiktok",
    "username": "Kap Onin",
    "avatarUrl":
        "https://assets.epuzzle.info/puzzle/158/484/original.jpg",
    "content":
        "https://www.tiktok.com/@ninoashlyelamne/video/7399878987020766481",
    "caption": "Solid Kap vibes!",
    "timestamp": "1d ago",
    "likes": 1500,
    "comments": 12,
    "replies": ["Lupet!", "Pa-shoutout!"]
  },
  {
    "type": "video",
    "username": "Kap Onin",
    "avatarUrl":
        "https://assets.epuzzle.info/puzzle/158/484/original.jpg",
    "content": "https://www.youtube.com/watch?v=g7_9zdSZ-UQ",
    "timestamp": "2d ago",
    "likes": 2300,
    "comments": 45,
    "replies": ["Solid Kap", "May bago nanaman akong walang natutunan"]
  },
];
