const std = @import("std");

const adw = @import("adw");
const gobject = @import("gobject");
const gtk = @import("gtk");

const gresource = @import("../build/gresource.zig");
const Common = @import("../class.zig").Common;

const log = std.log.scoped(.gtk_ghostty_search_overlay);

pub const SearchOverlay = extern struct {
    const Self = @This();
    parent_instance: Parent,
    pub const Parent = gtk.Box;
    pub const getGObjectType = gobject.ext.defineClass(Self, .{
        .name = "GhosttySearchOverlay",
        .instanceInit = &init,
        .classInit = &Class.init,
        .parent_class = &Class.parent,
        .private = .{ .Type = Private, .offset = &Private.offset },
    });

    pub const signals = struct {
        /// Emitted when the search text changes
        pub const search_changed = struct {
            pub const name = "search-changed";
            pub const connect = impl.connect;
            const impl = gobject.ext.defineSignal(
                name,
                Self,
                &.{[*:0]const u8},
                void,
            );
        };

        /// Emitted when next match is requested
        pub const search_next = struct {
            pub const name = "search-next";
            pub const connect = impl.connect;
            const impl = gobject.ext.defineSignal(
                name,
                Self,
                &.{},
                void,
            );
        };

        /// Emitted when previous match is requested
        pub const search_previous = struct {
            pub const name = "search-previous";
            pub const connect = impl.connect;
            const impl = gobject.ext.defineSignal(
                name,
                Self,
                &.{},
                void,
            );
        };

        /// Emitted when search is stopped (ESC pressed)
        pub const search_stopped = struct {
            pub const name = "search-stopped";
            pub const connect = impl.connect;
            const impl = gobject.ext.defineSignal(
                name,
                Self,
                &.{},
                void,
            );
        };
    };

    const Private = struct {
        /// The search bar widget
        search_bar: *gtk.SearchBar,

        /// The search entry widget
        search: *gtk.SearchEntry,

        /// Label showing match count (e.g., "3 of 15")
        counter: *gtk.Label,

        /// Previous match button
        button_previous: *gtk.Button,

        /// Next match button
        button_next: *gtk.Button,

        pub var offset: c_int = 0;
    };

    /// Create a new instance of the search overlay
    pub fn new() *Self {
        const self = gobject.ext.newInstance(Self, .{});
        return self.ref();
    }

    //---------------------------------------------------------------
    // Virtual Methods

    fn init(self: *Self, _: *Class) callconv(.c) void {
        gtk.Widget.initTemplate(self.as(gtk.Widget));
    }

    fn dispose(self: *Self) callconv(.c) void {
        gtk.Widget.disposeTemplate(
            self.as(gtk.Widget),
            getGObjectType(),
        );

        gobject.Object.virtual_methods.dispose.call(
            Class.parent,
            self.as(Parent),
        );
    }

    //---------------------------------------------------------------
    // Signal Handlers

    fn searchChanged(_: *gtk.SearchEntry, self: *SearchOverlay) callconv(.c) void {
        const priv = self.private();
        const text = gtk.Editable.getText(priv.search.as(gtk.Editable));

        signals.search_changed.impl.emit(
            self,
            null,
            .{text},
            null,
        );
    }

    fn searchStopped(_: *gtk.SearchEntry, self: *SearchOverlay) callconv(.c) void {
        // ESC was pressed - disable search mode and emit signal
        const priv = self.private();
        gtk.SearchBar.setSearchMode(priv.search_bar, 0);
        signals.search_stopped.impl.emit(
            self,
            null,
            .{},
            null,
        );
    }

    fn searchNext(_: *gtk.SearchEntry, self: *SearchOverlay) callconv(.c) void {
        signals.search_next.impl.emit(
            self,
            null,
            .{},
            null,
        );
    }

    fn searchPrevious(_: *gtk.SearchEntry, self: *SearchOverlay) callconv(.c) void {
        signals.search_previous.impl.emit(
            self,
            null,
            .{},
            null,
        );
    }

    fn previousClicked(_: *gtk.Button, self: *SearchOverlay) callconv(.c) void {
        signals.search_previous.impl.emit(
            self,
            null,
            .{},
            null,
        );
    }

    fn nextClicked(_: *gtk.Button, self: *SearchOverlay) callconv(.c) void {
        signals.search_next.impl.emit(
            self,
            null,
            .{},
            null,
        );
    }

    //---------------------------------------------------------------
    // Public Methods

    /// Update the match counter label (e.g., "3 of 15" or "No matches")
    pub fn updateCounter(self: *SearchOverlay, current: usize, total: usize) void {
        const priv = self.private();

        if (total == 0) {
            gtk.Label.setLabel(priv.counter, "No matches");
        } else {
            // Allocate a buffer for the counter text
            var buf: [64]u8 = undefined;
            const text = std.fmt.bufPrintZ(&buf, "{d} of {d}", .{ current, total }) catch {
                log.err("failed to format counter text", .{});
                return;
            };
            gtk.Label.setLabel(priv.counter, text);
        }
    }

    /// Clear the search entry
    pub fn clearSearch(self: *SearchOverlay) void {
        const priv = self.private();
        gtk.Editable.setText(priv.search.as(gtk.Editable), "");
    }

    /// Get the search mode state
    pub fn getSearchMode(self: *SearchOverlay) bool {
        const priv = self.private();
        return gtk.SearchBar.getSearchMode(priv.search_bar) != 0;
    }

    /// Set the search mode (show/hide the search bar)
    pub fn setSearchMode(self: *SearchOverlay, enabled: bool) void {
        const priv = self.private();
        gtk.SearchBar.setSearchMode(priv.search_bar, if (enabled) 1 else 0);

        // When enabling search mode, grab focus on the search entry
        if (enabled) {
            _ = priv.search.as(gtk.Widget).grabFocus();
        }
    }

    //---------------------------------------------------------------

    const C = Common(Self, Private);
    pub const as = C.as;
    pub const ref = C.ref;
    pub const refSink = C.refSink;
    pub const unref = C.unref;
    const private = C.private;

    pub const Class = extern struct {
        parent_class: Parent.Class,
        var parent: *Parent.Class = undefined;
        pub const Instance = Self;

        fn init(class: *Class) callconv(.c) void {
            gtk.Widget.Class.setTemplateFromResource(
                class.as(gtk.Widget.Class),
                comptime gresource.blueprint(.{
                    .major = 1,
                    .minor = 5,
                    .name = "search-overlay",
                }),
            );

            // Bind template children
            class.bindTemplateChildPrivate("search_bar", .{});
            class.bindTemplateChildPrivate("search", .{});
            class.bindTemplateChildPrivate("counter", .{});
            class.bindTemplateChildPrivate("button_previous", .{});
            class.bindTemplateChildPrivate("button_next", .{});

            // Bind template callbacks
            class.bindTemplateCallback("search_changed", &searchChanged);
            class.bindTemplateCallback("search_stopped", &searchStopped);
            class.bindTemplateCallback("search_next", &searchNext);
            class.bindTemplateCallback("search_previous", &searchPrevious);
            class.bindTemplateCallback("previous_clicked", &previousClicked);
            class.bindTemplateCallback("next_clicked", &nextClicked);

            // Register signals
            signals.search_changed.impl.register(.{});
            signals.search_next.impl.register(.{});
            signals.search_previous.impl.register(.{});
            signals.search_stopped.impl.register(.{});

            // Virtual methods
            gobject.Object.virtual_methods.dispose.implement(class, &dispose);
        }

        pub const as = C.Class.as;
        pub const bindTemplateChildPrivate = C.Class.bindTemplateChildPrivate;
        pub const bindTemplateCallback = C.Class.bindTemplateCallback;
    };
};
