# main.gd
# 루트 씬. 씬 전환의 컨테이너 역할만 함.
# 페이드 오버레이는 GameManager(Autoload) 자체 CanvasLayer에서 처리.
# 이 씬은 change_scene_to_file()로 교체되는 대상이므로
# 게임 로직을 두지 않음.

extends Node
