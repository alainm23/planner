/*
* Copyright © 2019 Alain M. (https://github.com/alainm23/planner)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Alain M. <alainmh23@gmail.com>
*/

public class Widgets.ScheduleButton : Gtk.ToggleButton {
    public Objects.Item item { get; construct; }
    public Objects.Duedate duedate { get; set; }

    private Gtk.Image due_image;
    private Gtk.Label due_label;
    private Gtk.Label time_label;
    private Gtk.Image repeat_image;
    private Gtk.Revealer time_revealer;
    private Gtk.Revealer repeat_revealer;
    private Gtk.Button clear_back_button;

    private Gtk.Popover popover = null;
    private Gtk.SearchEntry search_entry;
    private Widgets.Calendar.Calendar calendar;
    private Granite.Widgets.TimePicker time_picker;
    private Widgets.ScheduleRow today_row;
    private Widgets.ScheduleRow tomorrow_row;
    private Widgets.ScheduleRow calendar_row;
    private Widgets.ScheduleRow time_row;
    private Gtk.Stack stack;
    private Gtk.Revealer no_time_revealer;

    public signal void popover_opened (bool active);

    public ScheduleButton (Objects.Item item) {
        Object (
            item: item
        );
    }

    public ScheduleButton.new_item () {
        var item = new Objects.Item ();
        item.id = 0;

        Object (
            item: item
        );
    }

    construct {
        duedate = new Objects.Duedate ();

        if (item.id != 0) {
            duedate.date = new GLib.DateTime.from_iso8601 (item.due_date, new GLib.TimeZone.local ());
        }

        tooltip_text = _("Schedule");
        get_style_context ().add_class ("flat");
        get_style_context ().add_class ("item-action-button");

        due_image = new Gtk.Image ();
        due_image.valign = Gtk.Align.CENTER;
        due_image.pixel_size = 16;

        due_label = new Gtk.Label (_("Schedule"));
        due_label.use_markup = true;

        time_label = new Gtk.Label (null);
        time_label.get_style_context ().add_class ("no-padding");
        time_label.use_markup = true;

        time_revealer = new Gtk.Revealer ();
        time_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        time_revealer.add (time_label);
        time_revealer.reveal_child = false;

        repeat_image = new Gtk.Image ();
        repeat_image.valign = Gtk.Align.CENTER;
        repeat_image.pixel_size = 10;
        repeat_image.margin_top = 2;
        repeat_image.gicon = new ThemedIcon ("media-playlist-repeat-symbolic");

        repeat_revealer = new Gtk.Revealer ();
        repeat_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        repeat_revealer.add (repeat_image);

        var main_grid = new Gtk.Grid ();
        main_grid.halign = Gtk.Align.CENTER;
        main_grid.valign = Gtk.Align.CENTER;
        main_grid.add (due_image);
        main_grid.add (due_label);
        main_grid.add (time_revealer);
        main_grid.add (repeat_revealer);

        add (main_grid);

        toggled.connect (() => {
            if (active) {
                if (popover == null) {
                    create_popover ();
                }

                update_popover (duedate);

                popover.popup ();
            }
        });

        update_button (duedate);
        Planner.settings.changed.connect ((key) => {
            if (key == "appearance") {
                update_button (duedate);
            }
        });
    }

    private void create_popover () {
        popover = new Gtk.Popover (this);
        popover.position = Gtk.PositionType.BOTTOM;
        popover.get_style_context ().add_class ("popover-background");

        clear_back_button = new Gtk.Button.with_label (_("Clear"));
        clear_back_button.get_style_context ().add_class ("flat");
        clear_back_button.get_style_context ().add_class ("font-weight-600");
        clear_back_button.get_style_context ().add_class ("label-danger");
        clear_back_button.get_style_context ().add_class ("no-padding-left");
        clear_back_button.can_focus = false;

        var done_button = new Gtk.Button.with_label (_("Done"));
        done_button.get_style_context ().add_class ("flat");
        done_button.get_style_context ().add_class ("font-weight-600");
        done_button.get_style_context ().add_class ("no-padding-right");
        done_button.can_focus = false;

        var title_label = new Gtk.Label (_("Schedule"));
        title_label.get_style_context ().add_class ("font-bold");

        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        header_box.margin_start = 3;
        header_box.margin_end = 3;
        header_box.hexpand = true;
        header_box.pack_start (clear_back_button, false, false, 0);
        header_box.set_center_widget (title_label);
        header_box.pack_end (done_button, false, false, 0);

        stack = new Gtk.Stack ();
        stack.expand = true;
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

        stack.add_named (get_home_widget (), "home");
        stack.add_named (get_pick_date_widget (), "pick-date");
        stack.add_named (get_pick_time_widget (), "pick-time");

        var popover_grid = new Gtk.Grid ();
        popover_grid.margin_top = 6;
        popover_grid.margin_bottom = 6;
        popover_grid.width_request = 235;
        popover_grid.orientation = Gtk.Orientation.VERTICAL;
        popover_grid.add (header_box);
        popover_grid.add (stack);
        popover_grid.show_all ();

        popover.add (popover_grid);

        popover.closed.connect (() => {
            popover_opened (false);
            active = false;

            if (item.id != 0) {
                bool new_date = false;
                if (duedate.is_valid ()) {
                    if (item.due_date == "") {
                        new_date = true;
                    }

                    item.due_date = duedate.get_due_date ();
                } else {
                    item.due_date = "";
                    item.due_is_recurring = 0;
                    item.due_string = "";
                    item.due_lang = "";
                }

                Planner.database.set_due_item (item, new_date);
                if (item.is_todoist == 1) {
                    Planner.todoist.update_item (item);
                }
            }
        });

        popover.show.connect (() => {
            popover_opened (true);
        });

        done_button.clicked.connect (() => {
            popover.popdown ();
        });

        clear_back_button.clicked.connect (() => {
            if (stack.visible_child_name != "home") {
                stack.visible_child_name = "home";
                check_clear_back_button ();
            } else {
                duedate.date = null;
                update_popover (duedate);
                update_button (duedate);
                popover.popdown ();
            }
        });
    }

    private Gtk.Widget get_home_widget () {
        search_entry = new Gtk.SearchEntry ();
        search_entry.margin = 6;
        search_entry.margin_start = 9;
        search_entry.margin_end = 9;
        search_entry.hexpand = true;
        search_entry.get_style_context ().add_class ("border-radius-4");
        search_entry.get_style_context ().add_class ("popover-entry");

        today_row = new Widgets.ScheduleRow (_("Today"), "help-about-symbolic");
        today_row.item_image.get_style_context ().add_class ("today");
        tomorrow_row = new Widgets.ScheduleRow (_("Tomorrow"), "go-jump-symbolic");
        calendar_row = new Widgets.ScheduleRow (_("Pick Date"), "office-calendar-symbolic", true);
        time_row = new Widgets.ScheduleRow (_("Pick Time"), "appointment-new-symbolic", true);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        // grid.add (search_entry);
        grid.add (today_row);
        grid.add (tomorrow_row);
        grid.add (calendar_row);
        grid.add (time_row);

        today_row.clicked.connect (() => {
            set_date (Planner.utils.get_format_date (new DateTime.now_local ()));
        });

        tomorrow_row.clicked.connect (() => {
            set_date (Planner.utils.get_format_date (new DateTime.now_local ().add_days (1)));
        });

        calendar_row.clicked.connect (() => {
            stack.visible_child_name = "pick-date";
            check_clear_back_button ();
        });

        time_row.clicked.connect (() => {
            stack.visible_child_name = "pick-time";
            check_clear_back_button ();

            no_time_revealer.reveal_child = false;
            time_picker.grab_focus ();

            if (duedate.is_valid ()) {
                if (Planner.utils.has_time (duedate.date)) {
                    no_time_revealer.reveal_child = true;
                }
            }
        });

        return grid;
    }

    private Gtk.Widget get_pick_date_widget () {
        calendar = new Widgets.Calendar.Calendar (true);
        calendar.hexpand = true;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.add (calendar);

        calendar.selection_changed.connect ((date) => {
            set_date (Planner.utils.get_format_date (date));
            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        return grid;
    }

    private Gtk.Widget get_pick_time_widget () {
        time_picker = new Granite.Widgets.TimePicker ();
        time_picker.hexpand = true;
        time_picker.margin = 12;
        time_picker.margin_top = 24;
        time_picker.get_style_context ().add_class ("border-radius-4");
        time_picker.get_style_context ().add_class ("popover-entry");

        var morning_button = new Widgets.TimeAlternativeButton (_("Morning"), "morning-time");
        var afternoon_button = new Widgets.TimeAlternativeButton (_("Afternoon"), "afternoon-time");
        var evening_button = new Widgets.TimeAlternativeButton (_("Evening"), "evening-time");

        var times_grid = new Gtk.Grid ();
        times_grid.column_homogeneous = true;
        times_grid.add (morning_button);
        times_grid.add (afternoon_button);
        times_grid.add (evening_button);

        var set_time_button = new Gtk.Button.with_label (_("Set Time"));
        set_time_button.margin_top = 12;
        set_time_button.get_style_context ().add_class ("suggested-action");
        set_time_button.get_style_context ().add_class ("border-radius-50");
        set_time_button.halign = Gtk.Align.CENTER;

        var no_time_button = new Gtk.Button.with_label (_("No Time"));
        no_time_button.margin_top = 6;
        no_time_button.can_focus = false;
        no_time_button.get_style_context ().add_class ("flat");
        no_time_button.halign = Gtk.Align.CENTER;

        no_time_revealer = new Gtk.Revealer ();
        no_time_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        no_time_revealer.reveal_child = true;
        no_time_revealer.add (no_time_button);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.add (time_picker);
        grid.add (times_grid);
        grid.add (set_time_button);
        grid.add (no_time_revealer);

        set_time_button.clicked.connect (() => {
            set_time (time_picker.time);
            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        time_picker.activate.connect (() => {
            set_time (time_picker.time);
            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        morning_button.clicked.connect (() => {
            set_time (morning_button.time);
            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        afternoon_button.clicked.connect (() => {
            set_time (afternoon_button.time);
            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        evening_button.clicked.connect (() => {
            set_time (evening_button.time);
            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        no_time_button.clicked.connect (() => {
            duedate.no_time ();

            update_button (duedate);
            update_popover (duedate);

            stack.visible_child_name = "home";
            check_clear_back_button ();
        });

        return grid;
    }

    private void set_date (DateTime date) {
        if (Planner.utils.has_time (duedate.date)) {
            duedate.update_date (date);
        } else {
            duedate.date = date;
        }

        update_button (duedate);
        update_popover (duedate);
    }

    private void set_time (DateTime time) {
        if (duedate.is_valid ()) {
            duedate.set_time (time);
        } else {
            duedate.date = time;
        }

        update_button (duedate);
        update_popover (duedate);
    }

    private void check_clear_back_button () {
        if (stack.visible_child_name == "home") {
            clear_back_button.label = _("Clear");
            clear_back_button.get_style_context ().add_class ("label-danger");
        } else {
            clear_back_button.label = _("Back");
            clear_back_button.get_style_context ().remove_class ("label-danger");
        }
    }

    private void update_popover (Objects.Duedate duedate) {
        today_row.selected = false;
        tomorrow_row.selected = false;
        calendar_row.date_label = "";
        time_row.date_label = "";

        if (duedate.is_valid ()) {
            if (Planner.utils.is_today (duedate.date)) {
                today_row.selected = true;
            } else if (Planner.utils.is_tomorrow (duedate.date)) {
                tomorrow_row.selected = true;
            } else {
                calendar_row.date_label = Planner.utils.get_relative_date_from_date (duedate.date);
            }
    
            if (Planner.utils.has_time (duedate.date)) {
                time_row.date_label = duedate.date.format (Planner.utils.get_default_time_format ());
            }
        }
    }

    private void update_button (Objects.Duedate duedate) {
        due_label.label = _("Schedule");
        time_label.label = "";
        
        if (Planner.settings.get_enum ("appearance") == 0) {
            due_image.gicon = new ThemedIcon ("calendar-outline-light");
        } else {
            due_image.gicon = new ThemedIcon ("calendar-outline-dark");
        }

        due_image.get_style_context ().remove_class ("overdue-label");
        due_image.get_style_context ().remove_class ("today");
        due_image.get_style_context ().remove_class ("upcoming");

        repeat_revealer.reveal_child = false;
        time_revealer.reveal_child = false;

        if (duedate.is_valid ()) {
            due_label.label = Planner.utils.get_relative_date_from_date (duedate.date);
            if (Planner.utils.has_time (duedate.date)) {
                time_label.label = duedate.date.format (Planner.utils.get_default_time_format ());
                time_revealer.reveal_child = true;
            }

            if (Planner.utils.is_today (duedate.date)) {
                due_image.gicon = new ThemedIcon ("help-about-symbolic");
                due_image.get_style_context ().add_class ("today");
            } else if (Planner.utils.is_overdue (duedate.date)) {
                due_image.gicon = new ThemedIcon ("calendar-overdue");
                due_image.get_style_context ().add_class ("overdue-label");
            } else {
                if (Planner.settings.get_enum ("appearance") == 0) {
                    due_image.gicon = new ThemedIcon ("calendar-outline-light");
                } else {
                    due_image.gicon = new ThemedIcon ("calendar-outline-dark");
                }

                due_image.get_style_context ().add_class ("upcoming");
            }

            //  if (item.due_is_recurring == 1) {
            //      repeat_revealer.reveal_child = true;
            //  } else {
            //      repeat_revealer.reveal_child = false;
            //  }
        }
    }

    public void set_new_item_due_date (string due_date) {
        if (due_date != "") {
            duedate.date = Planner.utils.get_format_date_from_string (due_date);
            update_button (duedate);
        }
    }

    public string get_due_date () {
        var returned = "";

        if (duedate.is_valid ()) {
            returned = duedate.get_due_date ();
        }

        return returned;
    }
}

public class Widgets.ScheduleRow : Gtk.Button {
    public bool is_calendar { get; construct; }
    private Gtk.Label item_label;
    private Gtk.Revealer selected_revealer;
    public Gtk.Image item_image;
    public Gtk.Label preview_label;

    public string icon {
        set {
            item_image.gicon = new ThemedIcon (value);
        }
    }

    public string text {
        set {
            item_label.label = value;
        }
    }

    public bool selected {
        set {
            selected_revealer.reveal_child = value;
        }
    }

    public string date_label {
        set {
            preview_label.label = value;
        }
    }

    public ScheduleRow (string text, string icon, bool is_calendar=false) {
        Object (
            text: text,
            icon: icon,
            is_calendar: is_calendar
        );
    }

    construct {
        get_style_context ().remove_class ("button");
        get_style_context ().add_class ("flat");
        get_style_context ().add_class ("menuitem");
        get_style_context ().add_class ("no-border");
        can_focus = false;

        item_image = new Gtk.Image ();
        item_image.valign = Gtk.Align.CENTER;
        item_image.halign = Gtk.Align.CENTER;
        item_image.pixel_size = 16;

        item_label = new Gtk.Label (null);

        var selected_image = new Gtk.Image ();
        selected_image.valign = Gtk.Align.CENTER;
        selected_image.halign = Gtk.Align.CENTER;
        selected_image.pixel_size = 16;
        selected_image.gicon = new ThemedIcon ("object-select-symbolic");
        selected_image.get_style_context ().add_class ("inbox");

        selected_revealer = new Gtk.Revealer ();
        selected_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        selected_revealer.add (selected_image);

        var forward_image = new Gtk.Image ();
        forward_image.valign = Gtk.Align.CENTER;
        forward_image.halign = Gtk.Align.CENTER;
        forward_image.pixel_size = 16;
        forward_image.gicon = new ThemedIcon ("chevron-forward-symbolic");
        forward_image.get_style_context ().add_class ("inbox");

        preview_label = new Gtk.Label (null);
        preview_label.get_style_context ().add_class ("inbox");
        preview_label.get_style_context ().add_class ("font-weight-600");

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        box.margin_start = 3;
        box.margin_end = 3;
        box.pack_start (item_image, false, false, 0);
        box.pack_start (item_label, false, true, 0);

        if (is_calendar) {
            box.pack_end (forward_image, false, false, 0);
            box.pack_end (preview_label, false, false, 0);
        } else {
            box.pack_end (selected_revealer, false, false, 0);
        }

        add (box);
    }
}

public class Widgets.TimeAlternativeButton : Gtk.Button {
    public string text { get; construct; }
    public string key { get; construct; }
    public GLib.DateTime time { get; set; }

    private Gtk.Label title_label;
    private Gtk.Label time_label;

    public TimeAlternativeButton (string text, string key) {
        Object (
            text: text,
            key: key
        );
    }

    construct {
        get_style_context ().remove_class ("button");
        get_style_context ().add_class ("flat");
        get_style_context ().add_class ("menuitem");
        get_style_context ().add_class ("no-border");
        get_style_context ().add_class ("time-alternative");
        can_focus = false;
        int hour, minute;
        Planner.settings.get (key, "(ii)", out hour, out minute);

        time = Planner.utils.get_time_by_hour_minute (hour, minute);

        title_label = new Gtk.Label (text);
        title_label.get_style_context ().add_class ("font-bold");

        time_label = new Gtk.Label (time.format (Planner.utils.get_default_time_format ()));
        time_label.get_style_context ().add_class ("small-label");
        
        var grid = new Gtk.Grid ();
        grid.halign = Gtk.Align.CENTER;
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.add (title_label);
        grid.add (time_label);

        add (grid);
    }
}
