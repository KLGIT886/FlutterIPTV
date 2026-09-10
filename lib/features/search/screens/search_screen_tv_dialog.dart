part of 'search_screen.dart';

/// TV 端虚拟键盘搜索弹窗（从 _SearchScreenState 抽出的扩展）。
extension _SearchScreenTvDialog on _SearchScreenState {
  void _showTVSearchDialog() {
    final dialogController = TextEditingController(text: _searchQuery);
    final searchButtonFocusNode = FocusNode();
    final cancelButtonFocusNode = FocusNode();
    final inputFocusNode = FocusNode();
    bool isInputFocused = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.getSurfaceColor(context),
              title: Text(
                AppStrings.of(context)?.searchChannels ?? 'Search Channels',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 输入框区域 - 使用 Focus 包装来处理焦点
                    Focus(
                      onFocusChange: (hasFocus) {
                        setDialogState(() {
                          isInputFocused = hasFocus;
                        });
                      },
                      onKeyEvent: (node, event) {
                        // 当按下向下键时，移动焦点到搜索按钮
                        if (event is KeyDownEvent) {
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            searchButtonFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isInputFocused
                                ? AppTheme.getPrimaryColor(context)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: dialogController,
                          focusNode: inputFocusNode,
                          autofocus: true,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 18,
                          ),
                          decoration: InputDecoration(
                            hintText: AppStrings.of(context)?.searchHint ??
                                'Search channels...',
                            hintStyle: TextStyle(
                                color: AppTheme.getTextMuted(context)),
                            filled: true,
                            fillColor: AppTheme.getCardColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          onSubmitted: (value) {
                            refreshSearchUi(() {
                              _searchQuery = value;
                              _searchController.text = value;
                            });
                            Navigator.pop(dialogContext);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 取消按钮
                        Focus(
                          focusNode: cancelButtonFocusNode,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowUp) {
                                inputFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight) {
                                searchButtonFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                      LogicalKeyboardKey.select ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter) {
                                Navigator.pop(dialogContext);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Builder(
                            builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasFocus
                                        ? AppTheme.getPrimaryColor(context)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(
                                    AppStrings.of(context)?.cancel ?? 'Cancel',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 搜索按钮
                        Focus(
                          focusNode: searchButtonFocusNode,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowUp) {
                                inputFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowLeft) {
                                cancelButtonFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                      LogicalKeyboardKey.select ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter) {
                                refreshSearchUi(() {
                                  _searchQuery = dialogController.text;
                                  _searchController.text =
                                      dialogController.text;
                                });
                                Navigator.pop(dialogContext);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Builder(
                            builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasFocus
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    refreshSearchUi(() {
                                      _searchQuery = dialogController.text;
                                      _searchController.text =
                                          dialogController.text;
                                    });
                                    Navigator.pop(dialogContext);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppTheme.getPrimaryColor(context),
                                  ),
                                  child: Text(
                                    AppStrings.of(context)?.search ?? 'Search',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      searchButtonFocusNode.dispose();
      cancelButtonFocusNode.dispose();
      inputFocusNode.dispose();
    });
  }

}
