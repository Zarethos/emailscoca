/**
 * Premium Starter - Roundcube Skin JavaScript
 * Premium Creamy White & Light Orange Theme
 * Version: 2.0.0
 * Author: Premium Mail Team
 */

(function(window, document, $) {
    'use strict';

    /**
     * Premium Starter Skin Module
     */
    const PremiumStarter = {
        // Configuration
        config: {
            animationDuration: 300,
            notificationDuration: 5000,
            debounceDelay: 250,
            touchThreshold: 50,
            darkModeKey: 'premium_dark_mode',
            sidebarCollapsedKey: 'premium_sidebar_collapsed',
            version: '2.0.0'
        },

        // State
        state: {
            darkMode: false,
            sidebarCollapsed: false,
            touchStartX: 0,
            touchStartY: 0,
            isLoading: false,
            notifications: []
        },

        /**
         * Initialize the skin
         */
        init: function() {
            this.loadSettings();
            this.bindEvents();
            this.initComponents();
            this.applyEnhancements();
            console.log('Premium Starter Skin v' + this.config.version + ' initialized');
        },

        /**
         * Load saved settings from localStorage
         */
        loadSettings: function() {
            try {
                // Load dark mode preference
                const darkMode = localStorage.getItem(this.config.darkModeKey);
                if (darkMode === 'true') {
                    this.state.darkMode = true;
                    document.documentElement.classList.add('dark-mode');
                }

                // Load sidebar state
                const sidebarCollapsed = localStorage.getItem(this.config.sidebarCollapsedKey);
                if (sidebarCollapsed === 'true') {
                    this.state.sidebarCollapsed = true;
                    document.body.classList.add('sidebar-collapsed');
                }

                // Auto-detect system dark mode preference
                if (darkMode === null && window.matchMedia) {
                    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
                    if (prefersDark.matches) {
                        this.toggleDarkMode(true);
                    }
                    prefersDark.addEventListener('change', (e) => {
                        this.toggleDarkMode(e.matches);
                    });
                }
            } catch (e) {
                console.warn('Could not load settings from localStorage:', e);
            }
        },

        /**
         * Bind all event listeners
         */
        bindEvents: function() {
            const self = this;

            // Document ready
            $(document).ready(function() {
                self.onDocumentReady();
            });

            // Window resize
            let resizeTimer;
            $(window).on('resize', function() {
                clearTimeout(resizeTimer);
                resizeTimer = setTimeout(function() {
                    self.onWindowResize();
                }, self.config.debounceDelay);
            });

            // Keyboard shortcuts
            $(document).on('keydown', function(e) {
                self.handleKeyboardShortcuts(e);
            });

            // Touch events for swipe gestures
            document.addEventListener('touchstart', function(e) {
                self.handleTouchStart(e);
            }, { passive: true });

            document.addEventListener('touchend', function(e) {
                self.handleTouchEnd(e);
            }, { passive: true });

            // Handle AJAX loading states
            if (window.rcmail) {
                rcmail.addEventListener('init', function() {
                    self.onRoundcubeInit();
                });

                rcmail.addEventListener('responseafter', function() {
                    self.onAjaxComplete();
                });

                rcmail.addEventListener('beforerequest', function() {
                    self.onAjaxStart();
                });
            }
        },

        /**
         * Initialize UI components
         */
        initComponents: function() {
            this.initTooltips();
            this.initDropdowns();
            this.initModals();
            this.initTabs();
            this.initSearch();
            this.initSidebar();
            this.initNotifications();
        },

        /**
         * Apply theme enhancements
         */
        applyEnhancements: function() {
            this.enhanceLoginForm();
            this.enhanceMessageList();
            this.enhanceCompose();
            this.enhanceContacts();
            this.enhanceCalendar();
            this.enhanceSettings();
            this.addRippleEffect();
            this.addScrollReveal();
        },

        /**
         * Document ready handler
         */
        onDocumentReady: function() {
            // Add loaded class for animations
            document.body.classList.add('premium-loaded');

            // Hide preloader if exists
            const preloader = document.getElementById('preloader');
            if (preloader) {
                preloader.classList.add('fade-out');
                setTimeout(() => preloader.remove(), 500);
            }

            // Initialize lazy loading for images
            this.initLazyLoading();
        },

        /**
         * Roundcube init handler
         */
        onRoundcubeInit: function() {
            // Add custom actions
            if (rcmail.env.task === 'mail') {
                this.enhanceMailUI();
            } else if (rcmail.env.task === 'addressbook') {
                this.enhanceAddressbookUI();
            } else if (rcmail.env.task === 'settings') {
                this.enhanceSettingsUI();
            }
        },

        /**
         * Window resize handler
         */
        onWindowResize: function() {
            const width = window.innerWidth;

            // Toggle mobile mode
            if (width <= 768) {
                document.body.classList.add('mobile-view');
            } else {
                document.body.classList.remove('mobile-view');
            }

            // Adjust UI elements
            this.adjustLayout();
        },

        /**
         * AJAX start handler
         */
        onAjaxStart: function() {
            this.state.isLoading = true;
            document.body.classList.add('loading');
            
            // Show loading indicator
            this.showLoadingIndicator();
        },

        /**
         * AJAX complete handler
         */
        onAjaxComplete: function() {
            this.state.isLoading = false;
            document.body.classList.remove('loading');
            
            // Hide loading indicator
            this.hideLoadingIndicator();

            // Re-apply enhancements to new content
            this.applyEnhancements();
        },

        /**
         * Toggle dark mode
         */
        toggleDarkMode: function(enable) {
            this.state.darkMode = enable !== undefined ? enable : !this.state.darkMode;
            
            if (this.state.darkMode) {
                document.documentElement.classList.add('dark-mode');
            } else {
                document.documentElement.classList.remove('dark-mode');
            }

            try {
                localStorage.setItem(this.config.darkModeKey, this.state.darkMode);
            } catch (e) {}

            // Dispatch event for other components
            document.dispatchEvent(new CustomEvent('premium:darkModeChanged', {
                detail: { enabled: this.state.darkMode }
            }));
        },

        /**
         * Toggle sidebar
         */
        toggleSidebar: function() {
            this.state.sidebarCollapsed = !this.state.sidebarCollapsed;
            
            document.body.classList.toggle('sidebar-collapsed', this.state.sidebarCollapsed);

            try {
                localStorage.setItem(this.config.sidebarCollapsedKey, this.state.sidebarCollapsed);
            } catch (e) {}
        },

        /**
         * Initialize tooltips
         */
        initTooltips: function() {
            $('[data-tooltip]').each(function() {
                const $el = $(this);
                const text = $el.attr('data-tooltip');
                const position = $el.attr('data-tooltip-position') || 'top';

                $el.on('mouseenter', function() {
                    const tooltip = $('<div class="premium-tooltip"></div>')
                        .text(text)
                        .addClass('tooltip-' + position)
                        .appendTo('body');

                    const offset = $el.offset();
                    const elWidth = $el.outerWidth();
                    const elHeight = $el.outerHeight();
                    const tipWidth = tooltip.outerWidth();
                    const tipHeight = tooltip.outerHeight();

                    let top, left;

                    switch (position) {
                        case 'bottom':
                            top = offset.top + elHeight + 8;
                            left = offset.left + (elWidth - tipWidth) / 2;
                            break;
                        case 'left':
                            top = offset.top + (elHeight - tipHeight) / 2;
                            left = offset.left - tipWidth - 8;
                            break;
                        case 'right':
                            top = offset.top + (elHeight - tipHeight) / 2;
                            left = offset.left + elWidth + 8;
                            break;
                        default: // top
                            top = offset.top - tipHeight - 8;
                            left = offset.left + (elWidth - tipWidth) / 2;
                    }

                    tooltip.css({ top: top, left: left });

                    setTimeout(() => tooltip.addClass('visible'), 10);
                });

                $el.on('mouseleave', function() {
                    $('.premium-tooltip').removeClass('visible');
                    setTimeout(() => $('.premium-tooltip').remove(), 200);
                });
            });
        },

        /**
         * Initialize dropdowns
         */
        initDropdowns: function() {
            const self = this;

            // Toggle dropdown on click
            $(document).on('click', '.dropdown-toggle', function(e) {
                e.preventDefault();
                e.stopPropagation();

                const $dropdown = $(this).closest('.dropdown');
                const wasOpen = $dropdown.hasClass('open');

                // Close all other dropdowns
                $('.dropdown.open').removeClass('open');

                // Toggle current dropdown
                if (!wasOpen) {
                    $dropdown.addClass('open');

                    // Position dropdown menu
                    const $menu = $dropdown.find('.dropdown-menu');
                    self.positionDropdown($menu, $dropdown);
                }
            });

            // Close dropdown on outside click
            $(document).on('click', function() {
                $('.dropdown.open').removeClass('open');
            });

            // Close dropdown on escape
            $(document).on('keydown', function(e) {
                if (e.key === 'Escape') {
                    $('.dropdown.open').removeClass('open');
                }
            });
        },

        /**
         * Position dropdown menu
         */
        positionDropdown: function($menu, $container) {
            const containerOffset = $container.offset();
            const menuWidth = $menu.outerWidth();
            const menuHeight = $menu.outerHeight();
            const windowWidth = $(window).width();
            const windowHeight = $(window).height();

            // Check if menu goes off screen right
            if (containerOffset.left + menuWidth > windowWidth) {
                $menu.addClass('dropdown-right');
            } else {
                $menu.removeClass('dropdown-right');
            }

            // Check if menu goes off screen bottom
            if (containerOffset.top + menuHeight > windowHeight) {
                $menu.addClass('dropdown-up');
            } else {
                $menu.removeClass('dropdown-up');
            }
        },

        /**
         * Initialize modals
         */
        initModals: function() {
            // Open modal
            $(document).on('click', '[data-modal]', function(e) {
                e.preventDefault();
                const modalId = $(this).attr('data-modal');
                PremiumStarter.openModal(modalId);
            });

            // Close modal on backdrop click
            $(document).on('click', '.modal-overlay', function(e) {
                if (e.target === this) {
                    PremiumStarter.closeModal($(this).find('.modal, .dialog').attr('id'));
                }
            });

            // Close modal on close button click
            $(document).on('click', '.modal-close, .dialog-close, [data-modal-close]', function() {
                const $modal = $(this).closest('.modal, .dialog');
                PremiumStarter.closeModal($modal.attr('id'));
            });
        },

        /**
         * Open modal
         */
        openModal: function(modalId) {
            const $modal = $('#' + modalId);
            if (!$modal.length) return;

            // Create overlay if not exists
            let $overlay = $modal.parent('.modal-overlay');
            if (!$overlay.length) {
                $overlay = $('<div class="modal-overlay"></div>')
                    .append($modal)
                    .appendTo('body');
            }

            // Show modal
            $overlay.addClass('visible');
            $modal.addClass('visible');

            // Prevent body scroll
            document.body.style.overflow = 'hidden';

            // Focus first input
            setTimeout(() => {
                $modal.find('input, select, textarea, button').first().focus();
            }, 100);

            // Dispatch event
            $modal.trigger('modal:open');
        },

        /**
         * Close modal
         */
        closeModal: function(modalId) {
            const $modal = $('#' + modalId);
            if (!$modal.length) return;

            const $overlay = $modal.parent('.modal-overlay');

            $modal.removeClass('visible');
            $overlay.removeClass('visible');

            // Re-enable body scroll
            document.body.style.overflow = '';

            // Remove overlay after animation
            setTimeout(() => {
                if (!$overlay.hasClass('visible')) {
                    // Keep modal but hide overlay
                    $overlay.hide();
                }
            }, 300);

            // Dispatch event
            $modal.trigger('modal:close');
        },

        /**
         * Initialize tabs
         */
        initTabs: function() {
            $(document).on('click', '.tabs .tab', function(e) {
                e.preventDefault();
                const $tab = $(this);
                const $tabs = $tab.closest('.tabs');
                const targetId = $tab.attr('data-tab');

                // Update active tab
                $tabs.find('.tab').removeClass('active');
                $tab.addClass('active');

                // Update active content
                const $container = $tabs.parent();
                $container.find('.tab-content').removeClass('active');
                $container.find('#' + targetId).addClass('active');

                // Dispatch event
                $tabs.trigger('tab:change', [targetId]);
            });
        },

        /**
         * Initialize search
         */
        initSearch: function() {
            const self = this;
            let searchTimer;

            // Enhanced search input
            $(document).on('input', '#quicksearchbar input, .search-input', function() {
                const $input = $(this);
                const query = $input.val();

                clearTimeout(searchTimer);

                if (query.length >= 2) {
                    searchTimer = setTimeout(() => {
                        self.performSearch(query);
                    }, self.config.debounceDelay);
                }
            });

            // Search clear button
            $(document).on('click', '.search-clear', function() {
                const $container = $(this).closest('.search-container, #quicksearchbar');
                $container.find('input').val('').focus();
                $container.find('.search-results').hide();
            });
        },

        /**
         * Perform search
         */
        performSearch: function(query) {
            // This would integrate with Roundcube's search
            if (window.rcmail && rcmail.command) {
                rcmail.command('search', query);
            }
        },

        /**
         * Initialize sidebar
         */
        initSidebar: function() {
            const self = this;

            // Toggle sidebar
            $(document).on('click', '.sidebar-toggle, #sidebar-toggle', function() {
                self.toggleSidebar();
            });

            // Folder expand/collapse
            $(document).on('click', '.folder-toggle', function(e) {
                e.preventDefault();
                e.stopPropagation();

                const $li = $(this).closest('li');
                $li.toggleClass('expanded');
            });
        },

        /**
         * Initialize notifications
         */
        initNotifications: function() {
            // Create notification container if not exists
            if (!$('#premium-notifications').length) {
                $('<div id="premium-notifications"></div>').appendTo('body');
            }
        },

        /**
         * Show notification
         */
        showNotification: function(message, type, duration) {
            type = type || 'info';
            duration = duration || this.config.notificationDuration;

            const id = 'notification-' + Date.now();
            const icons = {
                success: '✓',
                error: '✕',
                warning: '⚠',
                info: 'ℹ'
            };

            const $notification = $(`
                <div id="${id}" class="notification ${type}">
                    <span class="notification-icon">${icons[type]}</span>
                    <div class="notification-content">
                        <div class="notification-message">${message}</div>
                    </div>
                    <button class="notification-close">✕</button>
                </div>
            `);

            $('#premium-notifications').append($notification);

            // Show with animation
            setTimeout(() => $notification.addClass('visible'), 10);

            // Auto hide
            if (duration > 0) {
                setTimeout(() => {
                    this.hideNotification(id);
                }, duration);
            }

            // Close button
            $notification.find('.notification-close').on('click', () => {
                this.hideNotification(id);
            });

            return id;
        },

        /**
         * Hide notification
         */
        hideNotification: function(id) {
            const $notification = $('#' + id);
            $notification.removeClass('visible');
            setTimeout(() => $notification.remove(), 300);
        },

        /**
         * Show loading indicator
         */
        showLoadingIndicator: function() {
            if (!$('#premium-loading').length) {
                $(`
                    <div id="premium-loading">
                        <div class="loading-spinner"></div>
                    </div>
                `).appendTo('body');
            }
            $('#premium-loading').addClass('visible');
        },

        /**
         * Hide loading indicator
         */
        hideLoadingIndicator: function() {
            $('#premium-loading').removeClass('visible');
        },

        /**
         * Enhance login form
         */
        enhanceLoginForm: function() {
            const $loginForm = $('#login-form');
            if (!$loginForm.length) return;

            // Add icon wrappers to inputs
            $loginForm.find('input[type="text"], input[type="password"]').each(function() {
                const $input = $(this);
                if (!$input.parent().hasClass('input-icon-wrapper')) {
                    const icon = $input.attr('type') === 'password' ? '🔒' : '👤';
                    $input.wrap('<div class="input-icon-wrapper"></div>');
                    $('<span class="input-icon">' + icon + '</span>').insertAfter($input);
                }
            });

            // Password visibility toggle
            $loginForm.find('input[type="password"]').each(function() {
                const $input = $(this);
                const $toggle = $('<button type="button" class="password-toggle">👁</button>');
                $toggle.insertAfter($input);

                $toggle.on('click', function(e) {
                    e.preventDefault();
                    const type = $input.attr('type') === 'password' ? 'text' : 'password';
                    $input.attr('type', type);
                    $(this).text(type === 'password' ? '👁' : '🙈');
                });
            });

            // Form validation enhancement
            $loginForm.find('input').on('blur', function() {
                const $input = $(this);
                if ($input.val()) {
                    $input.addClass('has-value');
                } else {
                    $input.removeClass('has-value');
                }
            });
        },

        /**
         * Enhance message list
         */
        enhanceMessageList: function() {
            const $messageList = $('#messagelist, .message-list');
            if (!$messageList.length) return;

            // Add hover preview
            $messageList.find('.message-item, tr').each(function() {
                const $item = $(this);
                
                // Add selection indicator
                if (!$item.find('.select-indicator').length) {
                    $item.prepend('<span class="select-indicator"></span>');
                }
            });

            // Swipe actions for mobile
            if ('ontouchstart' in window) {
                this.initSwipeActions($messageList);
            }
        },

        /**
         * Initialize swipe actions
         */
        initSwipeActions: function($container) {
            const self = this;

            $container.find('.message-item, tr').each(function() {
                const $item = $(this);
                let startX, startY, moving = false;

                $item.on('touchstart', function(e) {
                    const touch = e.touches[0];
                    startX = touch.clientX;
                    startY = touch.clientY;
                    moving = true;
                });

                $item.on('touchmove', function(e) {
                    if (!moving) return;
                    
                    const touch = e.touches[0];
                    const diffX = touch.clientX - startX;
                    const diffY = touch.clientY - startY;

                    // Check if horizontal swipe
                    if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 20) {
                        e.preventDefault();
                        $item.css('transform', 'translateX(' + diffX + 'px)');
                    }
                });

                $item.on('touchend', function(e) {
                    if (!moving) return;
                    moving = false;

                    const touch = e.changedTouches[0];
                    const diffX = touch.clientX - startX;

                    // Check swipe threshold
                    if (Math.abs(diffX) > self.config.touchThreshold) {
                        if (diffX > 0) {
                            // Swipe right - archive
                            self.handleSwipeAction($item, 'archive');
                        } else {
                            // Swipe left - delete
                            self.handleSwipeAction($item, 'delete');
                        }
                    } else {
                        $item.css('transform', '');
                    }
                });
            });
        },

        /**
         * Handle swipe action
         */
        handleSwipeAction: function($item, action) {
            $item.addClass('swipe-' + action);

            setTimeout(() => {
                if (action === 'delete' && window.rcmail) {
                    rcmail.command('delete');
                } else if (action === 'archive' && window.rcmail) {
                    rcmail.command('archive');
                }
            }, 300);
        },

        /**
         * Enhance compose view
         */
        enhanceCompose: function() {
            const $compose = $('#compose-form, .compose-form');
            if (!$compose.length) return;

            // Auto-resize textarea
            $compose.find('textarea').each(function() {
                const $textarea = $(this);

                $textarea.on('input', function() {
                    this.style.height = 'auto';
                    this.style.height = this.scrollHeight + 'px';
                });

                // Trigger initial resize
                $textarea.trigger('input');
            });

            // Recipient autocomplete enhancement
            $compose.find('input[name="_to"], input[name="_cc"], input[name="_bcc"]').each(function() {
                $(this).on('keydown', function(e) {
                    if (e.key === 'Tab' && $(this).val().includes('@')) {
                        // Auto-create tag
                        const value = $(this).val();
                        if (value) {
                            $(this).before(`<span class="tag">${value}<span class="tag-remove">✕</span></span>`);
                            $(this).val('');
                        }
                    }
                });
            });

            // Tag removal
            $compose.on('click', '.tag-remove', function() {
                $(this).parent('.tag').remove();
            });
        },

        /**
         * Enhance contacts
         */
        enhanceContacts: function() {
            const $contacts = $('#contacts-list, .contacts-list');
            if (!$contacts.length) return;

            // Add avatar initials if no image
            $contacts.find('.contact-item, tr').each(function() {
                const $item = $(this);
                const $avatar = $item.find('.contact-avatar');
                
                if ($avatar.length && !$avatar.find('img').length) {
                    const name = $item.find('.contact-name').text() || 
                                $item.find('.name').text() || '';
                    const initials = name.split(' ')
                        .map(n => n[0])
                        .slice(0, 2)
                        .join('')
                        .toUpperCase();
                    
                    $avatar.text(initials);
                }
            });
        },

        /**
         * Enhance calendar
         */
        enhanceCalendar: function() {
            const $calendar = $('#calendar, .calendar-container');
            if (!$calendar.length) return;

            // Add event tooltips
            $calendar.find('.calendar-event').each(function() {
                const $event = $(this);
                const title = $event.text();
                $event.attr('data-tooltip', title);
            });
        },

        /**
         * Enhance settings
         */
        enhanceSettings: function() {
            const $settings = $('#settings-sections, .settings-section');
            if (!$settings.length) return;

            // Add toggle switches for checkboxes
            $settings.find('input[type="checkbox"]').each(function() {
                const $checkbox = $(this);
                if (!$checkbox.parent().hasClass('toggle-switch')) {
                    const $wrapper = $('<label class="toggle-switch"></label>');
                    const $slider = $('<span class="toggle-slider"></span>');
                    
                    $checkbox.wrap($wrapper);
                    $checkbox.after($slider);
                }
            });
        },

        /**
         * Enhance mail UI
         */
        enhanceMailUI: function() {
            // Add quick action buttons
            const $toolbar = $('#toolbar, .toolbar');
            if ($toolbar.length && !$toolbar.find('.quick-actions').length) {
                const $quickActions = $(`
                    <div class="quick-actions">
                        <button class="btn btn-icon" data-tooltip="Refresh" onclick="rcmail.command('refresh')">🔄</button>
                        <button class="btn btn-icon" data-tooltip="Dark Mode" id="dark-mode-toggle">🌙</button>
                    </div>
                `);
                $toolbar.append($quickActions);

                // Dark mode toggle
                $('#dark-mode-toggle').on('click', () => {
                    this.toggleDarkMode();
                    const icon = this.state.darkMode ? '☀️' : '🌙';
                    $('#dark-mode-toggle').text(icon);
                });
            }
        },

        /**
         * Enhance addressbook UI
         */
        enhanceAddressbookUI: function() {
            // Add contact group colors
            $('#contactgrouplist li').each(function(index) {
                const colors = ['#FF9A4D', '#4CAF50', '#2196F3', '#9C27B0', '#F44336'];
                $(this).find('.name').prepend(`<span class="group-color" style="background:${colors[index % colors.length]}"></span>`);
            });
        },

        /**
         * Enhance settings UI
         */
        enhanceSettingsUI: function() {
            // Add icons to settings sections
            const icons = {
                'general': '⚙️',
                'mailbox': '📬',
                'mailview': '👁',
                'compose': '✏️',
                'addressbook': '📒',
                'folders': '📁',
                'server': '🖥️',
                'encryption': '🔐'
            };

            $('#settings-menu li a, #settings-sections .section-title').each(function() {
                const $el = $(this);
                const text = $el.text().toLowerCase();
                
                for (const [key, icon] of Object.entries(icons)) {
                    if (text.includes(key)) {
                        if (!$el.find('.section-icon').length) {
                            $el.prepend(`<span class="section-icon">${icon}</span>`);
                        }
                        break;
                    }
                }
            });
        },

        /**
         * Add ripple effect to buttons
         */
        addRippleEffect: function() {
            $(document).on('click', '.btn, button, .nav-list a, .dropdown-item', function(e) {
                const $el = $(this);
                
                // Remove existing ripple
                $el.find('.ripple').remove();

                // Create ripple
                const ripple = $('<span class="ripple"></span>');
                $el.css('position', 'relative').css('overflow', 'hidden');
                $el.append(ripple);

                // Position ripple
                const rect = this.getBoundingClientRect();
                const size = Math.max(rect.width, rect.height);
                const x = e.clientX - rect.left - size / 2;
                const y = e.clientY - rect.top - size / 2;

                ripple.css({
                    width: size,
                    height: size,
                    left: x,
                    top: y
                });

                // Remove after animation
                setTimeout(() => ripple.remove(), 600);
            });
        },

        /**
         * Add scroll reveal animations
         */
        addScrollReveal: function() {
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('revealed');
                    }
                });
            }, { threshold: 0.1 });

            document.querySelectorAll('.reveal-on-scroll').forEach(el => {
                observer.observe(el);
            });
        },

        /**
         * Initialize lazy loading
         */
        initLazyLoading: function() {
            const lazyImages = document.querySelectorAll('img[data-src]');

            if ('IntersectionObserver' in window) {
                const imageObserver = new IntersectionObserver((entries) => {
                    entries.forEach(entry => {
                        if (entry.isIntersecting) {
                            const img = entry.target;
                            img.src = img.dataset.src;
                            img.removeAttribute('data-src');
                            imageObserver.unobserve(img);
                        }
                    });
                });

                lazyImages.forEach(img => imageObserver.observe(img));
            } else {
                // Fallback for browsers without IntersectionObserver
                lazyImages.forEach(img => {
                    img.src = img.dataset.src;
                    img.removeAttribute('data-src');
                });
            }
        },

        /**
         * Handle keyboard shortcuts
         */
        handleKeyboardShortcuts: function(e) {
            // Don't trigger if in input field
            if ($(e.target).is('input, textarea, select')) return;

            const key = e.key.toLowerCase();
            const ctrl = e.ctrlKey || e.metaKey;
            const shift = e.shiftKey;

            // Ctrl+D: Toggle dark mode
            if (ctrl && key === 'd') {
                e.preventDefault();
                this.toggleDarkMode();
            }

            // Ctrl+B: Toggle sidebar
            if (ctrl && key === 'b') {
                e.preventDefault();
                this.toggleSidebar();
            }

            // Escape: Close modals
            if (key === 'escape') {
                $('.modal.visible, .dialog.visible').each(function() {
                    PremiumStarter.closeModal($(this).attr('id'));
                });
            }

            // /: Focus search
            if (key === '/' && !ctrl) {
                e.preventDefault();
                $('#quicksearchbar input, .search-input').first().focus();
            }

            // Roundcube specific shortcuts
            if (window.rcmail) {
                // C: Compose
                if (key === 'c' && !ctrl) {
                    e.preventDefault();
                    rcmail.command('compose');
                }

                // R: Reply
                if (key === 'r' && !ctrl && !shift) {
                    e.preventDefault();
                    rcmail.command('reply');
                }

                // Shift+R: Reply All
                if (key === 'r' && !ctrl && shift) {
                    e.preventDefault();
                    rcmail.command('reply-all');
                }

                // F: Forward
                if (key === 'f' && !ctrl) {
                    e.preventDefault();
                    rcmail.command('forward');
                }

                // Delete: Delete message
                if (key === 'delete') {
                    e.preventDefault();
                    rcmail.command('delete');
                }

                // J/K: Next/Previous message
                if (key === 'j') {
                    e.preventDefault();
                    rcmail.command('nextmessage');
                }
                if (key === 'k') {
                    e.preventDefault();
                    rcmail.command('previousmessage');
                }
            }
        },

        /**
         * Handle touch start
         */
        handleTouchStart: function(e) {
            this.state.touchStartX = e.touches[0].clientX;
            this.state.touchStartY = e.touches[0].clientY;
        },

        /**
         * Handle touch end
         */
        handleTouchEnd: function(e) {
            const diffX = e.changedTouches[0].clientX - this.state.touchStartX;
            const diffY = e.changedTouches[0].clientY - this.state.touchStartY;

            // Check if horizontal swipe
            if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 100) {
                // Sidebar toggle on edge swipe
                if (this.state.touchStartX < 30 && diffX > 0) {
                    // Swipe from left edge - open sidebar
                    this.state.sidebarCollapsed = false;
                    document.body.classList.remove('sidebar-collapsed');
                } else if (diffX < 0 && this.state.touchStartX < 300 && !this.state.sidebarCollapsed) {
                    // Swipe left on sidebar - close it
                    this.toggleSidebar();
                }
            }
        },

        /**
         * Adjust layout based on screen size
         */
        adjustLayout: function() {
            const width = window.innerWidth;
            const $sidebar = $('#layout-sidebar');
            const $list = $('#layout-list');
            const $content = $('#layout-content');

            if (width <= 768) {
                // Mobile: Stack layout
                $sidebar.attr('data-layout', 'mobile');
                $list.attr('data-layout', 'mobile');
                $content.attr('data-layout', 'mobile');
            } else if (width <= 1024) {
                // Tablet: Compact layout
                $sidebar.attr('data-layout', 'tablet');
                $list.attr('data-layout', 'tablet');
                $content.attr('data-layout', 'tablet');
            } else {
                // Desktop: Full layout
                $sidebar.attr('data-layout', 'desktop');
                $list.attr('data-layout', 'desktop');
                $content.attr('data-layout', 'desktop');
            }
        },

        /**
         * Utility: Format date
         */
        formatDate: function(date, format) {
            const d = new Date(date);
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            
            format = format || 'short';

            if (format === 'short') {
                return `${months[d.getMonth()]} ${d.getDate()}`;
            } else if (format === 'long') {
                return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
            } else if (format === 'time') {
                return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
            }
            
            return d.toLocaleDateString();
        },

        /**
         * Utility: Format file size
         */
        formatFileSize: function(bytes) {
            if (bytes === 0) return '0 Bytes';
            
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        },

        /**
         * Utility: Debounce function
         */
        debounce: function(func, wait) {
            let timeout;
            return function executedFunction(...args) {
                const later = () => {
                    clearTimeout(timeout);
                    func(...args);
                };
                clearTimeout(timeout);
                timeout = setTimeout(later, wait);
            };
        },

        /**
         * Utility: Throttle function
         */
        throttle: function(func, limit) {
            let inThrottle;
            return function(...args) {
                if (!inThrottle) {
                    func(...args);
                    inThrottle = true;
                    setTimeout(() => inThrottle = false, limit);
                }
            };
        }
    };

    // Add CSS for JavaScript-generated elements
    const dynamicStyles = `
        <style id="premium-dynamic-styles">
            /* Loading indicator */
            #premium-loading {
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                height: 3px;
                background: transparent;
                z-index: 9999;
                opacity: 0;
                transition: opacity 0.3s;
            }

            #premium-loading.visible {
                opacity: 1;
            }

            #premium-loading .loading-spinner {
                position: absolute;
                top: 0;
                left: 0;
                height: 100%;
                width: 30%;
                background: linear-gradient(90deg, transparent, var(--premium-orange), transparent);
                animation: loading-slide 1s infinite;
            }

            @keyframes loading-slide {
                0% { left: -30%; }
                100% { left: 100%; }
            }

            /* Notifications */
            #premium-notifications {
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 9998;
                display: flex;
                flex-direction: column;
                gap: 10px;
            }

            #premium-notifications .notification {
                transform: translateX(120%);
                transition: transform 0.3s ease-out;
            }

            #premium-notifications .notification.visible {
                transform: translateX(0);
            }

            #premium-notifications .notification-icon {
                font-size: 1.2rem;
                margin-right: 12px;
            }

            #premium-notifications .notification-content {
                flex: 1;
            }

            #premium-notifications .notification-close {
                background: none;
                border: none;
                padding: 4px;
                cursor: pointer;
                opacity: 0.5;
                transition: opacity 0.2s;
            }

            #premium-notifications .notification-close:hover {
                opacity: 1;
            }

            /* Tooltips */
            .premium-tooltip {
                position: fixed;
                padding: 8px 12px;
                background: var(--premium-text-primary);
                color: var(--premium-text-inverse);
                font-size: 0.85rem;
                font-weight: 500;
                border-radius: 6px;
                white-space: nowrap;
                z-index: 10000;
                opacity: 0;
                transform: translateY(4px);
                transition: opacity 0.2s, transform 0.2s;
                pointer-events: none;
            }

            .premium-tooltip.visible {
                opacity: 1;
                transform: translateY(0);
            }

            .premium-tooltip::after {
                content: '';
                position: absolute;
                border: 6px solid transparent;
            }

            .premium-tooltip.tooltip-top::after {
                top: 100%;
                left: 50%;
                transform: translateX(-50%);
                border-top-color: var(--premium-text-primary);
            }

            .premium-tooltip.tooltip-bottom::after {
                bottom: 100%;
                left: 50%;
                transform: translateX(-50%);
                border-bottom-color: var(--premium-text-primary);
            }

            /* Ripple effect */
            .ripple {
                position: absolute;
                border-radius: 50%;
                background: rgba(255, 255, 255, 0.4);
                transform: scale(0);
                animation: ripple-effect 0.6s ease-out;
                pointer-events: none;
            }

            @keyframes ripple-effect {
                to {
                    transform: scale(4);
                    opacity: 0;
                }
            }

            /* Reveal on scroll */
            .reveal-on-scroll {
                opacity: 0;
                transform: translateY(20px);
                transition: opacity 0.6s, transform 0.6s;
            }

            .reveal-on-scroll.revealed {
                opacity: 1;
                transform: translateY(0);
            }

            /* Password toggle */
            .password-toggle {
                position: absolute;
                right: 12px;
                top: 50%;
                transform: translateY(-50%);
                background: none;
                border: none;
                cursor: pointer;
                font-size: 1.1rem;
                opacity: 0.6;
                transition: opacity 0.2s;
            }

            .password-toggle:hover {
                opacity: 1;
            }

            /* Select indicator */
            .select-indicator {
                position: absolute;
                left: 0;
                top: 0;
                bottom: 0;
                width: 3px;
                background: var(--premium-orange);
                transform: scaleX(0);
                transform-origin: left;
                transition: transform 0.2s;
            }

            .message-item.selected .select-indicator,
            tr.selected .select-indicator {
                transform: scaleX(1);
            }

            /* Quick actions */
            .quick-actions {
                display: flex;
                gap: 8px;
                margin-left: auto;
            }

            /* Group color */
            .group-color {
                display: inline-block;
                width: 8px;
                height: 8px;
                border-radius: 50%;
                margin-right: 8px;
            }

            /* Section icon */
            .section-icon {
                margin-right: 10px;
                font-size: 1.1em;
            }

            /* Swipe actions */
            .message-item, tr {
                transition: transform 0.3s, background 0.3s;
            }

            .swipe-delete {
                background: var(--premium-danger-bg) !important;
                transform: translateX(-100%) !important;
            }

            .swipe-archive {
                background: var(--premium-success-bg) !important;
                transform: translateX(100%) !important;
            }

            /* Mobile view adjustments */
            .mobile-view #layout-sidebar {
                position: fixed;
                left: -280px;
                top: 0;
                bottom: 0;
                z-index: 1000;
                transition: left 0.3s;
            }

            .mobile-view #layout-sidebar.open {
                left: 0;
            }

            .mobile-view.sidebar-collapsed #layout-sidebar {
                left: -280px;
            }

            /* Sidebar collapsed state */
            .sidebar-collapsed #layout-sidebar {
                width: 60px;
            }

            .sidebar-collapsed #layout-sidebar .nav-list a span,
            .sidebar-collapsed #layout-sidebar .folder-name {
                display: none;
            }

            /* Preloader fade out */
            #preloader.fade-out {
                opacity: 0;
                visibility: hidden;
                transition: opacity 0.5s, visibility 0.5s;
            }

            /* Body loaded state */
            body.premium-loaded {
                /* Ready for interactions */
            }
        </style>
    `;

    // Inject dynamic styles
    $(function() {
        $('head').append(dynamicStyles);
    });

    // Initialize on load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            PremiumStarter.init();
        });
    } else {
        PremiumStarter.init();
    }

    // Export to global scope
    window.PremiumStarter = PremiumStarter;

})(window, document, window.jQuery);
