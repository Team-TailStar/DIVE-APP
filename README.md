# DIVE-APP

### 2025-Spring-Project-Frontend
### team 404Found

### 개발환경 설치
[Flutter 공식 설치 가이드 (Windows)](https://docs.flutter.dev/get-started/install/windows)
```
Flutter 설치
1) 위 링크로 가서 Flutter SDK 다운로드
2) 적당한 경로에 압축 해제 ( ex) C:\src\flutter)
3) 시스템 환경변수 > Path > C:\src\flutter\bin 추가
4) cmd에 flutter doctor 명령어 입력
5) Android Studio 설치 및  Android SDK 설정

패키지 설치
flutter pub get

에뮬레이터 실행
flutter devices
flutter run

api 키 없이 임의로 실행
flutter run --dart-define=USE_TIDE_MOCK=true
```

### 프로젝트 구조
```
project-root/
│
├── lib/
│   ├── main.dart     
│   ├── routes.dart
│   └── pages/
│      └── sea_weather/
│          └── sea_weather.dart 
│      └── tide/
│          ├── tide_models.dart
│          ├── tide_page.dart
│          └── tide_services.dart
│
├── pubspec.yaml 
├── analysis_options.yaml
├── .gitignore
├── README.md         
```
