import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function()? onExpanded;
  final Function()? onCollapsed;
  final String hintText;
  
  const AnimatedSearchBar({
    super.key,
    required this.onSearch,
    this.onExpanded,
    this.onCollapsed,
    this.hintText = 'Search...',
  });
  
  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // We'll initialize the animation in build or didChangeDependencies to get correct screen width
    _searchController.addListener(() {
      widget.onSearch(_searchController.text);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-calculate expansion width based on screen size
    _widthAnimation = Tween<double>(
      begin: 48.0,
      end: MediaQuery.of(context).size.width - 48, // Adaptive width
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _expand() {
    setState(() {
      _isExpanded = true;
    });
    _controller.forward();
    _focusNode.requestFocus();
    widget.onExpanded?.call();
  }
  
  void _collapse() {
    setState(() {
      _isExpanded = false;
    });
    _controller.reverse();
    _focusNode.unfocus();
    _searchController.clear();
    widget.onCollapsed?.call();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _isExpanded ? AppTheme.surfaceDark : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: _isExpanded
              ? Border.all(color: AppTheme.primaryPurple.withOpacity(0.5), width: 1.5)
              : null,
            boxShadow: _isExpanded ? [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ] : null,
          ),
          child: Row(
            children: [
              // Search icon or back button
              GestureDetector(
                onTap: _isExpanded ? _collapse : _expand,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(
                    _isExpanded ? Icons.arrow_back_rounded : Icons.search_rounded,
                    color: _isExpanded 
                      ? AppTheme.primaryPurple 
                      : Colors.white.withOpacity(0.8),
                    size: 22,
                  ),
                ),
              ),
              
              // Text field (visible when expanded)
              if (_isExpanded)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: false, // Managed by _expand()
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.5),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              
              // Clear button
              if (_isExpanded && _searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppTheme.textSecondary,
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
