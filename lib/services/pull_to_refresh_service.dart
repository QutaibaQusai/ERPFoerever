// lib/services/pull_to_refresh_service.dart - FIXED SHEET VERSION with Dynamic Content Support
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum RefreshContext {
  mainScreen,
  webViewPage,
  sheetWebView,
}

class PullToRefreshService {
  static final PullToRefreshService _instance = PullToRefreshService._internal();
  factory PullToRefreshService() => _instance;
  PullToRefreshService._internal();

  /// Inject native pull-to-refresh functionality into a WebView
  void injectNativePullToRefresh({
    required WebViewController controller,
    required RefreshContext context,
    required String refreshChannelName,
    int tabIndex = 0,
    BuildContext? flutterContext,
  }) {
    try {
      final contextName = _getContextName(context);
      final elementId = _getElementId(context, tabIndex);
      final thresholds = _getThresholds(context);
      final positioning = _getPositioning(context);
      
      debugPrint('🔄 Injecting FIXED pull-to-refresh for $contextName...');

      // Get current theme from Flutter
      String currentFlutterTheme = 'light';
      if (flutterContext != null) {
        final brightness = Theme.of(flutterContext).brightness;
        currentFlutterTheme = brightness == Brightness.dark ? 'dark' : 'light';
      }

      controller.runJavaScript('''
      (function() {
        console.log('🔄 Starting FIXED pull-to-refresh for $contextName...');
        
        // Configuration
        const PULL_THRESHOLD = ${thresholds['pullThreshold']};
        const MIN_PULL_SPEED = ${thresholds['minPullSpeed']};
        const channelName = '$refreshChannelName';
        const contextName = '$contextName';
        const elementId = '$elementId';
        const isSheetContext = '$contextName' === 'WEBVIEW SHEET';
        ${tabIndex > 0 ? 'const tabIndex = $tabIndex;' : ''}
        
        // Remove any existing refresh elements
        const existing = document.getElementById(elementId);
        if (existing) existing.remove();
        
        // State variables
        let startY = 0;
        let currentPull = 0;
        let maxPull = 0;
        let isPulling = false;
        let isRefreshing = false;
        let canPull = false;
        let hasReachedThreshold = false;
        let refreshBlocked = false;
        let currentTheme = '$currentFlutterTheme';
        
        // ENHANCED: Dynamic content tracking for sheets
        let lastScrollTop = 0;
        let touchStartTime = 0;
        let initialTouchY = 0;
        window.lastContentChangeTime = window.lastContentChangeTime || 0;
        
        // Function to detect current theme
        function detectCurrentTheme() {
          return currentTheme;
        }
        
        // Function to get theme colors
        function getThemeColors(theme) {
          if (theme === 'dark') {
            return {
              background: 'rgba(40, 40, 40, 0.95)',
              progressDefault: '#60A5FA',
              progressReady: '#34D399',
              shadow: '0 4px 12px rgba(0, 0, 0, 0.4)'
            };
          } else {
            return {
              background: 'rgba(255, 255, 255, 0.95)',
              progressDefault: '#0078d7',
              progressReady: '#28a745',
              shadow: '0 2px 8px rgba(0, 0, 0, 0.15)'
            };
          }
        }
        
        // Function to check if refresh is allowed
        function isRefreshAllowed() {
          return !refreshBlocked;
        }
        
        // Function for Flutter to update refresh state
        window.setRefreshBlocked = function(blocked) {
          refreshBlocked = blocked;
          console.log('🔄 ' + contextName + ' refresh state updated:', blocked ? 'BLOCKED' : 'ALLOWED');
          
          if (blocked && isPulling) {
            isPulling = false;
            currentPull = 0;
            maxPull = 0;
            canPull = false;
            hasReachedThreshold = false;
            if (refreshDiv) {
              hideRefresh();
            }
          }
        };
        
        // Function for Flutter to update theme
        window.updateRefreshTheme = function(newTheme) {
          if (newTheme && newTheme !== currentTheme) {
            console.log('🎨 Flutter theme update for ' + contextName + ': ' + currentTheme + ' → ' + newTheme);
            currentTheme = newTheme;
            updateIndicatorTheme();
            return true;
          }
          return false;
        };
        
        // ENHANCED: Top detection with CHAT-SPECIFIC scroll position checking
        function isAtTop() {
          // Get scroll position from multiple sources with debouncing
          const scrollTop1 = window.pageYOffset || 0;
          const scrollTop2 = document.documentElement.scrollTop || 0;
          const scrollTop3 = document.body.scrollTop || 0;
          const scrollTop = Math.max(scrollTop1, scrollTop2, scrollTop3);
          
          if (isSheetContext) {
            // CRITICAL: For sheets, use STRICT detection with chat-specific checking
            const isExactlyAtTop = scrollTop === 0;
            
            // LAG FIX: Double-check scroll position after small delay to catch lag
            if (isExactlyAtTop && window.lagCheckTimeout) {
              clearTimeout(window.lagCheckTimeout);
            }
            
            // Additional check: ensure we're not in the middle of content updates
            const hasRecentContentChange = window.lastContentChangeTime && 
              (Date.now() - window.lastContentChangeTime) < 1000;
            
            // CHAT-SPECIFIC FIX: Check for chat/message containers more aggressively
            const chatSelectors = [
              '[style*="overflow"]',
              '.chat-container', 
              '.message-container', 
              '.content-container',
              '[data-dynamic-content="true"]',
              // AI Assistant specific selectors
              '[class*="chat"]',
              '[class*="message"]',
              '[class*="conversation"]',
              '[id*="chat"]',
              '[id*="message"]',
              // Generic scrollable areas
              'div[style*="overflow-y"]',
              'div[style*="scroll"]',
              '.scroll',
              '.scrollable',
              // Common chat UI patterns
              'main',
              'section',
              'article'
            ];
            
            const scrollableElements = document.querySelectorAll(chatSelectors.join(', '));
            let allContainersAtTop = true;
            let maxContainerScroll = 0;
            let scrolledContainerInfo = [];
            
            for (let element of scrollableElements) {
              const elementScrollTop = element.scrollTop || 0;
              if (elementScrollTop > 0) {
                allContainersAtTop = false;
                maxContainerScroll = Math.max(maxContainerScroll, elementScrollTop);
                scrolledContainerInfo.push({
                  element: element.tagName + '.' + (element.className || 'no-class'),
                  scrollTop: elementScrollTop
                });
              }
            }
            
            // ADDITIONAL CHECK: Look for any element that might be a scrollable chat area
            const allDivs = document.querySelectorAll('div');
            for (let div of allDivs) {
              const style = window.getComputedStyle(div);
              const hasOverflow = style.overflowY === 'scroll' || style.overflowY === 'auto';
              const hasHeight = div.scrollHeight > div.clientHeight;
              const scrollTop = div.scrollTop || 0;
              
              if (hasOverflow && hasHeight && scrollTop > 0) {
                allContainersAtTop = false;
                maxContainerScroll = Math.max(maxContainerScroll, scrollTop);
                scrolledContainerInfo.push({
                  element: 'computed-' + div.tagName + '.' + (div.className || 'no-class'),
                  scrollTop: scrollTop
                });
              }
            }
            
            // LAG FIX: Check if we're actually scrolling (velocity detection)
            const now = Date.now();
            const timeDiff = now - (window.lastScrollCheck || now);
            const scrollDiff = scrollTop - (window.lastScrollPosition || scrollTop);
            const scrollVelocity = timeDiff > 0 ? Math.abs(scrollDiff / timeDiff) : 0;
            
            window.lastScrollCheck = now;
            window.lastScrollPosition = scrollTop;
            
            // If scroll velocity is high, we're actively scrolling - be more strict
            const isActivelyScrolling = scrollVelocity > 0.5;
            
            const finalResult = isExactlyAtTop && 
                               allContainersAtTop && 
                               !hasRecentContentChange && 
                               !isActivelyScrolling &&
                               maxContainerScroll === 0;
            
            // Enhanced logging for debugging
            if (!finalResult) {
              console.log('📍 Sheet CHAT-FIXED check - NOT AT TOP:', {
                scrollTop: scrollTop,
                maxContainerScroll: maxContainerScroll,
                isActivelyScrolling: isActivelyScrolling,
                scrollVelocity: scrollVelocity.toFixed(2),
                scrolledContainers: scrolledContainerInfo.length,
                scrolledContainerDetails: scrolledContainerInfo
              });
            }
            
            return finalResult;
          } else {
            // For main screen and regular webview, allow small tolerance
            return scrollTop <= 3;
          }
        }
        
        // Create refresh indicator with dynamic theming
        const refreshDiv = document.createElement('div');
        refreshDiv.id = elementId;
        
        refreshDiv.innerHTML = \`
          <div class="refresh-circle">
            <svg class="refresh-svg" width="24" height="24" viewBox="0 0 24 24">
              <circle class="refresh-progress" cx="12" cy="12" r="10" fill="none" stroke-width="2" 
                      stroke-linecap="round" stroke-dasharray="63" stroke-dashoffset="63" 
                      transform="rotate(-90 12 12)"/>
            </svg>
          </div>
        \`;
        
        // Function to update indicator theme
        function updateIndicatorTheme() {
          const theme = detectCurrentTheme();
          const colors = getThemeColors(theme);
          console.log('🎨 Updating ' + contextName + ' refresh indicator theme to:', theme);
          
          refreshDiv.style.background = colors.background;
          refreshDiv.style.boxShadow = colors.shadow;
          
          const progressCircle = refreshDiv.querySelector('.refresh-progress');
          if (progressCircle) {
            if (hasReachedThreshold) {
              progressCircle.style.stroke = colors.progressReady;
            } else {
              progressCircle.style.stroke = colors.progressDefault;
            }
          }
          
          document.documentElement.style.setProperty('--refresh-default-color', colors.progressDefault);
          document.documentElement.style.setProperty('--refresh-ready-color', colors.progressReady);
        }
        
        // Set positioning based on context
        refreshDiv.style.cssText = \`
          position: ${positioning['position']};
          top: ${positioning['top']};
          left: 50%;
          transform: ${positioning['transform']};
          width: 40px;
          height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 9999;
          border-radius: 50%;
          opacity: 0;
          transition: all 0.2s ease;
          pointer-events: none;
        \`;
        
        // Add styles
        const circleStyles = document.createElement('style');
        circleStyles.innerHTML = \`
          :root {
            --refresh-default-color: #0078d7;
            --refresh-ready-color: #28a745;
          }
          
          .refresh-circle {
            width: 24px;
            height: 24px;
          }
          
          .refresh-svg {
            width: 100%;
            height: 100%;
          }
          
          .refresh-progress {
            transition: stroke-dashoffset 0.1s ease-out, stroke 0.2s ease;
            stroke: var(--refresh-default-color);
          }
          
          .refresh-ready .refresh-progress {
            stroke: var(--refresh-ready-color) !important;
          }
          
          .refresh-spinning .refresh-svg {
            animation: simpleRefreshSpin 1s linear infinite;
          }
          
          .refresh-spinning .refresh-progress {
            stroke: var(--refresh-default-color) !important;
            stroke-dasharray: 16;
            stroke-dashoffset: 0;
            animation: simpleRefreshProgress 1.2s ease-in-out infinite;
          }
          
          @keyframes simpleRefreshSpin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
          
          @keyframes simpleRefreshProgress {
            0% { stroke-dasharray: 16; stroke-dashoffset: 16; }
            50% { stroke-dasharray: 16; stroke-dashoffset: 0; }
            100% { stroke-dasharray: 16; stroke-dashoffset: -16; }
          }
        \`;
        
        document.head.appendChild(circleStyles);
        document.body.appendChild(refreshDiv);
        
        // Initial theme setup
        updateIndicatorTheme();
        
        // Prevent overscroll and setup proper scroll area for sheets
        if (isSheetContext) {
          document.body.style.cssText += \`
            overscroll-behavior-y: contain;
            overflow-anchor: none;
            -webkit-overflow-scrolling: touch;
            padding-top: 0px;
          \`;
          
          document.documentElement.style.scrollPaddingTop = '0px';
          document.body.style.marginTop = '0px';
        } else {
          document.body.style.cssText += \`
            overscroll-behavior-y: contain;
            overflow-anchor: none;
            -webkit-overflow-scrolling: touch;
          \`;
        }
        
        // Update refresh indicator
        function updateRefresh(distance) {
          const progress = Math.min(distance / PULL_THRESHOLD, 1);
          
          refreshDiv.style.opacity = progress > 0.1 ? '1' : '0';
          
          // Special handling for sheet context to show in scroll area
          if (isSheetContext) {
            const translateY = Math.min(distance * 0.5, 80) - 60;
            refreshDiv.style.transform = \`translateX(-50%) translateY(\${translateY}px)\`;
            
            if (progress > 0.1) {
              const bodyTransform = Math.min(distance * 0.3, 30);
              document.body.style.transform = \`translateY(\${bodyTransform}px)\`;
              document.body.style.transition = 'transform 0.1s ease-out';
            }
          }
          
          const circleProgress = progress * 100;
          const strokeDashoffset = 63 - (circleProgress * 0.63);
          const progressCircle = refreshDiv.querySelector('.refresh-progress');
          progressCircle.style.strokeDashoffset = strokeDashoffset;
          
          refreshDiv.classList.remove('refresh-ready');
          if (progress >= 1) {
            hasReachedThreshold = true;
            refreshDiv.classList.add('refresh-ready');
          } else {
            hasReachedThreshold = false;
          }
          
          updateIndicatorTheme();
          
          console.log(\`🔄 \${contextName} animation: \${Math.round(progress * 100)}% (theme: \${currentTheme})\`);
        }
        
        // Hide indicator
        function hideRefresh() {
          refreshDiv.style.opacity = '0';
          refreshDiv.classList.remove('refresh-ready', 'refresh-spinning');
          refreshDiv.querySelector('.refresh-progress').style.strokeDashoffset = '63';
          hasReachedThreshold = false;
          
          // Reset body transform for sheet context
          if (isSheetContext) {
            document.body.style.transform = 'translateY(0px)';
            document.body.style.transition = 'transform 0.2s ease-out';
            refreshDiv.style.transform = 'translateX(-50%) translateY(-60px)';
          }
          
          updateIndicatorTheme();
        }
        
        // Start refreshing animation
        function doRefresh() {
          if (isRefreshing || !hasReachedThreshold || !isRefreshAllowed()) {
            console.log(\`❌ \${contextName} refresh denied\`);
            hideRefresh();
            return;
          }
          
          console.log('✅ ' + contextName.toUpperCase() + ' REFRESH TRIGGERED!');
          isRefreshing = true;
          
          refreshDiv.classList.remove('refresh-ready');
          refreshDiv.classList.add('refresh-spinning');
          refreshDiv.style.opacity = '1';
          
          // Position during refresh for sheet context
          if (isSheetContext) {
            refreshDiv.style.transform = 'translateX(-50%) translateY(20px)';
            document.body.style.transform = 'translateY(20px)';
          }
          
          updateIndicatorTheme();
          
          if (window[channelName]) {
            window[channelName].postMessage('refresh');
            console.log('📤 ' + contextName + ' refresh message sent');
          }
          
          setTimeout(() => {
            hideRefresh();
            isRefreshing = false;
          }, 1500);
        }
        
        // ENHANCED: Touch event handlers with LAG-FREE scroll detection
        document.addEventListener('touchstart', function(e) {
          if (isRefreshing || !isRefreshAllowed()) return;
          
          touchStartTime = Date.now();
          
          // LAG FIX: Initialize scroll tracking
          window.lastScrollCheck = Date.now();
          window.lastScrollPosition = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          
          // LAG FIX: Wait a small moment to ensure scroll position is settled
          setTimeout(function() {
            if (!e.defaultPrevented) {
              const currentlyAtTop = isAtTop();
              const currentScrollTop = Math.max(
                window.pageYOffset || 0,
                document.documentElement.scrollTop || 0,
                document.body.scrollTop || 0
              );
              
              // Store initial scroll position to detect scroll direction
              lastScrollTop = currentScrollTop;
              
              if (currentlyAtTop) {
                canPull = true;
                startY = e.touches[0].clientY;
                initialTouchY = e.touches[0].clientY;
                currentPull = 0;
                maxPull = 0;
                isPulling = false;
                hasReachedThreshold = false;
                
                if (isSheetContext) {
                  console.log('👆 Sheet LAG-FIXED: Touch start EXACTLY at TOP (scroll: ' + currentScrollTop + 'px) - ready to pull');
                } else {
                  console.log('👆 ' + contextName + ': Touch start at TOP - ready to pull');
                }
              } else {
                canPull = false;
                if (isSheetContext) {
                  console.log('🚫 Sheet LAG-FIXED: Touch start NOT at exact top - scroll position:', currentScrollTop + 'px - NO PULL ALLOWED');
                }
              }
            }
          }, 10); // Small delay to avoid lag issues
          
        }, { passive: false });
        
        document.addEventListener('touchmove', function(e) {
          if (!canPull || isRefreshing || !isRefreshAllowed()) return;
          
          const currentY = e.touches[0].clientY;
          const deltaY = currentY - startY;
          
          // LAG FIX: Get current scroll position with multiple checks
          const currentScrollTop = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          
          // ENHANCED: Continuously check if still at top during touch move for sheets
          if (isSheetContext) {
            // LAG FIX: Use immediate check instead of function call during touch move
            const isExactlyAtTop = currentScrollTop === 0;
            
            // LAG FIX: Check all containers immediately with CHAT-SPECIFIC selectors
            const chatSelectors = [
              '[style*="overflow"]',
              '.chat-container', 
              '.message-container', 
              '.content-container',
              '[data-dynamic-content="true"]',
              // AI Assistant specific selectors
              '[class*="chat"]',
              '[class*="message"]',
              '[class*="conversation"]',
              '[id*="chat"]',
              '[id*="message"]',
              // Generic scrollable areas
              'div[style*="overflow-y"]',
              'div[style*="scroll"]',
              '.scroll',
              '.scrollable',
              // Common chat UI patterns
              'main',
              'section',
              'article'
            ];
            
            const scrollableElements = document.querySelectorAll(chatSelectors.join(', '));
            let allContainersAtTop = true;
            let maxContainerScroll = 0;
            let scrolledContainerInfo = [];
            
            for (let element of scrollableElements) {
              const elementScrollTop = element.scrollTop || 0;
              if (elementScrollTop > 0) {
                allContainersAtTop = false;
                maxContainerScroll = Math.max(maxContainerScroll, elementScrollTop);
                scrolledContainerInfo.push({
                  element: element.tagName + '.' + (element.className || 'no-class'),
                  scrollTop: elementScrollTop
                });
              }
            }
            
            // CRITICAL: Additional deep check for computed overflow elements
            const allDivs = document.querySelectorAll('div');
            for (let div of allDivs) {
              const style = window.getComputedStyle(div);
              const hasOverflow = style.overflowY === 'scroll' || style.overflowY === 'auto';
              const hasHeight = div.scrollHeight > div.clientHeight;
              const scrollTop = div.scrollTop || 0;
              
              if (hasOverflow && hasHeight && scrollTop > 0) {
                allContainersAtTop = false;
                maxContainerScroll = Math.max(maxContainerScroll, scrollTop);
                scrolledContainerInfo.push({
                  element: 'computed-' + div.tagName + '.' + (div.className || 'no-class'),
                  scrollTop: scrollTop
                });
              }
            }
            
            const stillAtTop = isExactlyAtTop && allContainersAtTop;
            
            // CRITICAL FIX: Detect if user is scrolling the page content (not pulling to refresh)
            // If scroll position changed from when touch started, this is page scrolling, not pull-to-refresh
            if (currentScrollTop !== lastScrollTop) {
              console.log('🛑 Sheet LAG-FIXED: Page scrolling detected (was: ' + lastScrollTop + 'px, now: ' + currentScrollTop + 'px) - cancelling pull');
              isPulling = false;
              hideRefresh();
              canPull = false;
              return;
            }
            
            // LAG FIX: Additional check for any container scrolling with CHAT-SPECIFIC detection
            if (maxContainerScroll > 0) {
              console.log('🛑 Sheet CHAT-FIXED: Container scrolling detected - Details:', {
                maxContainerScroll: maxContainerScroll,
                scrolledContainers: scrolledContainerInfo
              });
              isPulling = false;
              hideRefresh();
              canPull = false;
              return;
            }
            
            // ENHANCED: Check for dynamic content changes during touch
            const hasContentChanged = window.lastContentChangeTime && 
              (Date.now() - window.lastContentChangeTime) < 500;
            
            if (hasContentChanged) {
              console.log('🛑 Sheet: Dynamic content change detected during touch - cancelling pull');
              isPulling = false;
              hideRefresh();
              canPull = false;
              return;
            }
            
            // If not at top anymore, immediately cancel
            if (!stillAtTop) {
              console.log('🛑 Sheet LAG-FIXED: NO LONGER at top (scroll: ' + currentScrollTop + 'px, containerScroll: ' + maxContainerScroll + 'px) - cancelling pull');
              isPulling = false;
              hideRefresh();
              canPull = false;
              return;
            }
            
            // Only allow pull if:
            // 1. Pulling down (deltaY > 0)
            // 2. Still at exact top (stillAtTop)
            // 3. Scroll position hasn't changed (no page scrolling)
            // 4. No recent content changes
            // 5. No container scrolling
            if (deltaY > 0 && stillAtTop && currentScrollTop === 0 && !hasContentChanged && maxContainerScroll === 0) {
              currentPull = deltaY;
              maxPull = Math.max(maxPull, deltaY);
              
              if (deltaY >= MIN_PULL_SPEED) {
                e.preventDefault();
                isPulling = true;
                updateRefresh(deltaY);
                console.log('🔄 Sheet LAG-FIXED: Valid pull -', deltaY + 'px (still at exact top, no scrolling, no content changes)');
              }
            } else {
              if (deltaY <= 0) {
                console.log('🛑 Sheet: Pulling up - cancelling');
              } else if (!stillAtTop) {
                console.log('🛑 Sheet LAG-FIXED: Not at top anymore - cancelling');
              } else if (currentScrollTop !== 0) {
                console.log('🛑 Sheet: Scroll position changed - cancelling');
              } else if (hasContentChanged) {
                console.log('🛑 Sheet: Content changed during pull - cancelling');
              } else if (maxContainerScroll > 0) {
                console.log('🛑 Sheet LAG-FIXED: Container is scrolled - cancelling');
              }
              isPulling = false;
              hideRefresh();
              canPull = false;
            }
          } else {
            // Original logic for non-sheet contexts
            if (deltaY > 0 && isAtTop()) {
              currentPull = deltaY;
              maxPull = Math.max(maxPull, deltaY);
              
              if (deltaY >= MIN_PULL_SPEED) {
                e.preventDefault();
                isPulling = true;
                updateRefresh(deltaY);
              }
            } else if (isPulling) {
              isPulling = false;
              hideRefresh();
              canPull = false;
              console.log('🛑 ' + contextName + ': Stopped pulling - not at top or scrolling up');
            }
          }
        }, { passive: false });
        
        document.addEventListener('touchend', function(e) {
          if (!isPulling || isRefreshing || !isRefreshAllowed()) {
            // Reset all states
            isPulling = false;
            canPull = false;
            hasReachedThreshold = false;
            return;
          }
          
          // FINAL ENHANCED CHECK: Must still be at top for sheets
          const finallyAtTop = isAtTop();
          const validPull = hasReachedThreshold && maxPull >= PULL_THRESHOLD;
          
          if (isSheetContext) {
            // ENHANCED: Must be exactly at top AND have valid pull AND no recent content changes
            const hasRecentContentChange = window.lastContentChangeTime && 
              (Date.now() - window.lastContentChangeTime) < 500;
            const canRefresh = finallyAtTop && validPull && !hasRecentContentChange;
            
            const currentScrollTop = Math.max(
              window.pageYOffset || 0,
              document.documentElement.scrollTop || 0,
              document.body.scrollTop || 0
            );
            
            console.log('🏁 Sheet ENHANCED FINAL CHECK:', {
              finallyAtTop: finallyAtTop,
              validPull: validPull,
              hasRecentContentChange: hasRecentContentChange,
              canRefresh: canRefresh,
              maxPull: maxPull,
              threshold: PULL_THRESHOLD,
              scrollTop: currentScrollTop
            });
            
            if (canRefresh) {
              console.log('✅ SHEET SUCCESS: Valid pull-to-refresh from exact top with no content changes!');
              doRefresh();
            } else {
              console.log('❌ SHEET FAIL: Not at exact top, insufficient pull, or content changed recently');
              hideRefresh();
            }
          } else {
            if (validPull && finallyAtTop) {
              console.log('✅ ' + contextName.toUpperCase() + ' SUCCESS: User pulled to threshold at top - refreshing!');
              doRefresh();
            } else {
              console.log('❌ ' + contextName.toUpperCase() + ' FAIL: Not enough pull or not at top');
              hideRefresh();
            }
          }
          
          // Reset all states
          isPulling = false;
          canPull = false;
          currentPull = 0;
          maxPull = 0;
          startY = 0;
          hasReachedThreshold = false;
        }, { passive: false });
        
        document.addEventListener('touchcancel', function(e) {
          hideRefresh();
          isPulling = false;
          canPull = false;
          hasReachedThreshold = false;
          currentPull = 0;
          maxPull = 0;
        }, { passive: true });
        
        // ENHANCED: Monitor for dynamic content changes (specifically for sheets)
        if (isSheetContext) {
          // Track content changes to prevent pull-to-refresh during updates
          let contentObserver = new MutationObserver(function(mutations) {
            let hasSignificantChange = false;
            
            mutations.forEach(function(mutation) {
              // Check for significant DOM changes
              if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                // Check if added nodes contain significant content
                for (let node of mutation.addedNodes) {
                  if (node.nodeType === Node.ELEMENT_NODE && 
                      (node.textContent.length > 10 || node.querySelectorAll('*').length > 0)) {
                    hasSignificantChange = true;
                    break;
                  }
                }
              }
              
              // Check for text content changes in chat-like elements
              if (mutation.type === 'characterData' && mutation.target.textContent.length > 10) {
                hasSignificantChange = true;
              }
              
              // Check for attribute changes that might indicate content updates
              if (mutation.type === 'attributes' && 
                  (mutation.attributeName === 'class' || mutation.attributeName === 'style') &&
                  mutation.target.closest('.chat-container, .message-container, .content-container, [data-dynamic-content="true"]')) {
                hasSignificantChange = true;
              }
            });
            
            if (hasSignificantChange) {
              window.lastContentChangeTime = Date.now();
              console.log('📝 Sheet: Dynamic content change detected at', new Date().toLocaleTimeString());
              
              // If currently pulling, cancel it
              if (isPulling) {
                console.log('🛑 Sheet: Cancelling pull due to content change');
                isPulling = false;
                hideRefresh();
                canPull = false;
              }
            }
          });
          
          // Start observing for content changes
          contentObserver.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true,
            attributes: true,
            attributeFilter: ['class', 'style']
          });
          
          // Also observe specific chat/content containers when they appear
          function observeNewContainers() {
            const containers = document.querySelectorAll('.chat-container, .message-container, .content-container, [class*="chat"], [class*="message"], [data-dynamic-content="true"]');
            containers.forEach(function(container) {
              if (!container.hasAttribute('data-observed')) {
                container.setAttribute('data-observed', 'true');
                container.setAttribute('data-dynamic-content', 'true');
                
                const containerObserver = new MutationObserver(function() {
                  window.lastContentChangeTime = Date.now();
                  console.log('📝 Sheet: Content change in container:', container.className || container.tagName);
                });
                
                containerObserver.observe(container, {
                  childList: true,
                  subtree: true,
                  characterData: true
                });
              }
            });
          }
          
          // Initial scan for containers
          setTimeout(observeNewContainers, 1000);
          
          // Periodic scan for new containers
          setInterval(observeNewContainers, 5000);
          
          console.log('👁️ Sheet: Enhanced content change monitoring started for dynamic content');
        }
        
        console.log('✅ ' + contextName.toUpperCase() + ' ENHANCED pull-to-refresh ready with dynamic content support!');
        console.log('🎨 Current theme from Flutter:', currentTheme);
        console.log('📋 Sheet-specific ENHANCED mode:', isSheetContext ? 'ENABLED (scroll must be exactly 0px + no content changes)' : 'DISABLED');
        
      })();
      ''');

      debugPrint('✅ ENHANCED pull-to-refresh injected for $contextName with dynamic content support');
    } catch (e) {
      debugPrint('❌ Error injecting enhanced pull-to-refresh: $e');
    }
  }

  String _getContextName(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        return 'MAIN SCREEN';
      case RefreshContext.webViewPage:
        return 'WEBVIEW PAGE';
      case RefreshContext.sheetWebView:
        return 'WEBVIEW SHEET';
    }
  }

  String _getElementId(RefreshContext context, int tabIndex) {
    switch (context) {
      case RefreshContext.mainScreen:
        return 'enhanced-refresh-main-$tabIndex';
      case RefreshContext.webViewPage:
        return 'enhanced-refresh-page';
      case RefreshContext.sheetWebView:
        return 'enhanced-refresh-sheet';
    }
  }

  Map<String, int> _getThresholds(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        return {'pullThreshold': 450, 'minPullSpeed': 150};
      case RefreshContext.webViewPage:
        return {'pullThreshold': 450, 'minPullSpeed': 150};
      case RefreshContext.sheetWebView:
        // ENHANCED: Increased thresholds for better control with dynamic content
        return {'pullThreshold': 500, 'minPullSpeed': 200};
    }
  }

  Map<String, String> _getPositioning(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        return {
          'position': 'fixed',
          'top': '10px',
          'transform': 'translateX(-50%)',
        };
      case RefreshContext.webViewPage:
        return {
          'position': 'fixed',
          'top': '10px',
          'transform': 'translateX(-50%)',
        };
      case RefreshContext.sheetWebView:
        return {
          'position': 'absolute',
          'top': '0px',
          'transform': 'translateX(-50%) translateY(-60px)',
        };
    }
  }
}