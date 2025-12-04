;;; ridiculous-coding.el --- Over-the-top coding effects -*- lexical-binding: t -*-
;;; Commentary:
;; Port of https://github.com/jotson/ridiculous_coding (Godot plugin)
;; Makes your coding experience absurdly dramatic with:
;; - Explosions and particles on typing
;; - Screen shake
;; - Sound effects (cross-platform)
;; - Combo counters
;; - Different effects for different actions
;;
;; Toggle with M-x ridiculous-coding-mode
;; Go full chaos with M-x global-ridiculous-coding-mode
;;; Code:

(require 'cl-lib)

;;; ============================================================================
;;; Package Root
;;; ============================================================================

(defconst ridiculous-coding--root
  (file-name-directory (or load-file-name buffer-file-name))
  "Root directory of the ridiculous-coding package.")

;;; ============================================================================
;;; Customization
;;; ============================================================================

(defgroup ridiculous-coding nil
  "Over-the-top visual nonsense while you type."
  :group 'convenience
  :prefix "ridiculous-coding-")

(defcustom ridiculous-coding-intensity 0.25
  "Base probability (0-1) that an effect fires on each keypress.
Higher values = more chaos."
  :type 'float)

(defcustom ridiculous-coding-sound-enabled t
  "Whether to play sound effects."
  :type 'boolean)

(defcustom ridiculous-coding-sound-volume 0.5
  "Volume for sound effects (0.0-1.0). Only works on some platforms."
  :type 'float)

(defcustom ridiculous-coding-sounds-directory
  (expand-file-name "sounds" ridiculous-coding--root)
  "Directory containing sound effect files.
Expected subdirs: typing/, delete/, save/, combo/"
  :type 'directory)

(defcustom ridiculous-coding-images-directory
  (expand-file-name "images" ridiculous-coding--root)
  "Directory containing image sprite sheets.
Expected files: blip.png, boom.png, newline.png"
  :type 'directory)

(defcustom ridiculous-coding-images-enabled t
  "Whether to use image animations (GUI mode only).
Falls back to text effects in terminal."
  :type 'boolean)

(defcustom ridiculous-coding-shake-enabled t
  "Whether to enable screen shake effects."
  :type 'boolean)

(defcustom ridiculous-coding-particles-enabled t
  "Whether to enable particle/explosion effects."
  :type 'boolean)

(defcustom ridiculous-coding-combo-enabled t
  "Whether to track and display combo counter."
  :type 'boolean)

(defcustom ridiculous-coding-combo-timeout 2.0
  "Seconds of inactivity before combo resets."
  :type 'float)

(defcustom ridiculous-coding-combo-threshold 10
  "Combo count needed to trigger bonus effects."
  :type 'integer)

(defcustom ridiculous-coding-rainbow-enabled t
  "Whether to enable rainbow trail on typed characters."
  :type 'boolean)

(defcustom ridiculous-coding-spirits-enabled t
  "Whether characters float upward like escaping souls."
  :type 'boolean)

(defcustom ridiculous-coding-shockwave-enabled t
  "Whether to show expanding shockwave rings."
  :type 'boolean)

(defcustom ridiculous-coding-flash-enabled t
  "Whether to flash the screen on big combos."
  :type 'boolean)

(defcustom ridiculous-coding-afterimage-enabled t
  "Whether typed characters leave ghostly afterimages."
  :type 'boolean)

(defcustom ridiculous-coding-key-puff-enabled t
  "Whether to show typed keys as expanding puffs."
  :type 'boolean)

(defcustom ridiculous-coding-demo-mode nil
  "When non-nil, fire ALL effects on EVERY keystroke. For recordings."
  :type 'boolean)

;;; ============================================================================
;;; Internal State
;;; ============================================================================

(defvar-local ridiculous-coding--overlays nil
  "Active overlays for effects.")

(defvar-local ridiculous-coding--combo-count 0
  "Current combo counter.")

(defvar-local ridiculous-coding--combo-timer nil
  "Timer for combo timeout.")

(defvar-local ridiculous-coding--last-action nil
  "Last action type: typing, delete, save.")

;;; ============================================================================
;;; Platform Detection & Sound
;;; ============================================================================

(defun ridiculous-coding--platform ()
  "Return platform identifier: macos, linux, or other."
  (cond
   ((eq system-type 'darwin) 'macos)
   ((eq system-type 'gnu/linux) 'linux)
   (t 'other)))

(defun ridiculous-coding--sound-command ()
  "Return the sound playback command for current platform."
  (pcase (ridiculous-coding--platform)
    ('macos (executable-find "afplay"))
    ('linux (or (executable-find "paplay")
                (executable-find "aplay")
                (executable-find "play")))  ; sox
    (_ nil)))

(defun ridiculous-coding--play-sound (category)
  "Play a random sound from CATEGORY (typing, delete, save, combo).
Sounds are loaded from `ridiculous-coding-sounds-directory'/CATEGORY/."
  (when (and ridiculous-coding-sound-enabled
             (ridiculous-coding--sound-command))
    (let* ((dir (expand-file-name (symbol-name category)
                                  ridiculous-coding-sounds-directory))
           (files (and (file-directory-p dir)
                       (directory-files dir t "\\.\\(wav\\|mp3\\|ogg\\|aiff\\)$")))
           (sound (and files (nth (random (length files)) files)))
           (cmd (ridiculous-coding--sound-command)))
      (when sound
        ;; Let sounds overlap for maximum chaos!
        ;; Don't kill previous sounds - that caused them to be silenced
        ;; before they could actually play when typing rapidly.
        (pcase (ridiculous-coding--platform)
          ('macos
           (start-process "ridiculous-sound" nil cmd "-v" "1" sound))
          ('linux
           (start-process "ridiculous-sound" nil cmd sound)))))))

;;; ============================================================================
;;; Visual Effects: Particles & Explosions
;;; ============================================================================

(defconst ridiculous-coding--explosion-chars
  '("*" "+" "x" "X" "o" "O" "." ":" "!" "#" "@" "$" "%" "&")
  "Characters used for explosion particles.")

(defconst ridiculous-coding--explosion-faces
  '((:foreground "#FF6B6B" :weight bold)
    (:foreground "#FFE66D" :weight bold)
    (:foreground "#4ECDC4" :weight bold)
    (:foreground "#FF8C42" :weight bold)
    (:foreground "#A855F7" :weight bold)
    (:foreground "#22D3EE" :weight bold))
  "Faces for explosion particles (colorful!).")

(defun ridiculous-coding--random-element (list)
  "Return random element from LIST."
  (nth (random (length list)) list))

(defun ridiculous-coding--spawn-particle (pos char face duration)
  "Spawn a particle overlay at POS with CHAR, FACE, lasting DURATION seconds."
  (when (and (>= pos (point-min)) (<= pos (point-max)))
    (let ((ov (make-overlay pos (min (1+ pos) (point-max)))))
      (overlay-put ov 'priority 9999)
      (overlay-put ov 'ridiculous t)
      (overlay-put ov 'display (propertize char 'face face))
      (push ov ridiculous-coding--overlays)
      (run-at-time duration nil #'ridiculous-coding--remove-overlay ov))))

(defun ridiculous-coding--remove-overlay (ov)
  "Remove overlay OV and clean up."
  (when (overlayp ov)
    (delete-overlay ov)
    (setq ridiculous-coding--overlays
          (delq ov ridiculous-coding--overlays))))

(defun ridiculous-coding--cleanup-overlays ()
  "Remove all ridiculous overlays."
  (mapc #'delete-overlay ridiculous-coding--overlays)
  (setq ridiculous-coding--overlays nil))

(defun ridiculous-coding--kill-buffer-cleanup ()
  "Full cleanup for buffer kill - overlays and timers."
  (ridiculous-coding--cleanup-overlays)
  (ridiculous-coding--cleanup-region-effects)
  (setq ridiculous-coding--region-active-p nil)
  (setq ridiculous-coding--region-bounds nil)
  (ridiculous-coding--reset-combo))

(defun ridiculous-coding--explosion-at-point ()
  "Create an explosion effect at point."
  (when ridiculous-coding-particles-enabled
    (let* ((pos (point))
           (num-particles (+ 3 (random 5))))
      (dotimes (_ num-particles)
        (let* ((offset (- (random 7) 3))  ; -3 to +3
               (particle-pos (+ pos offset))
               (char (ridiculous-coding--random-element
                      ridiculous-coding--explosion-chars))
               (face (ridiculous-coding--random-element
                      ridiculous-coding--explosion-faces))
               (duration (+ 0.05 (* (random 10) 0.01))))  ; 0.05-0.15s
          (ridiculous-coding--spawn-particle particle-pos char face duration))))))

(defun ridiculous-coding--big-explosion ()
  "Create a BIG explosion (for combos, saves, etc.)."
  (when ridiculous-coding-particles-enabled
    (let* ((pos (point))
           (num-particles (+ 8 (random 8))))
      (dotimes (_ num-particles)
        (let* ((offset (- (random 15) 7))  ; wider spread
               (particle-pos (+ pos offset))
               (char (ridiculous-coding--random-element
                      ridiculous-coding--explosion-chars))
               (face (ridiculous-coding--random-element
                      ridiculous-coding--explosion-faces))
               (duration (+ 0.1 (* (random 15) 0.01))))
          (ridiculous-coding--spawn-particle particle-pos char face duration))))))

;;; ============================================================================
;;; Visual Effects: Screen Shake
;;; ============================================================================

(defun ridiculous-coding--shake (intensity)
  "Shake the screen with given INTENSITY (1-3)."
  (when ridiculous-coding-shake-enabled
    (let* ((win (selected-window))
           (orig-margins (window-margins win))
           (left (or (car orig-margins) 0))
           (right (or (cdr orig-margins) 0))
           (dx (* intensity 1)))
      (cl-flet ((set-m (delta)
                  (set-window-margins win (max 0 (+ left delta)) right)))
        ;; Quick jiggle sequence
        (set-m dx)
        (run-at-time 0.02 nil (lambda () (set-m (- dx))))
        (run-at-time 0.04 nil (lambda () (set-m dx)))
        (run-at-time 0.06 nil (lambda () (set-m 0)))))))

(defun ridiculous-coding--small-shake ()
  "Small screen shake for regular typing."
  (ridiculous-coding--shake 1))

(defun ridiculous-coding--big-shake ()
  "Big screen shake for deletes, saves, combos."
  (ridiculous-coding--shake 2))

;;; ============================================================================
;;; Visual Effects: INSANE MODE
;;; ============================================================================

;; Rainbow color cycle
(defconst ridiculous-coding--rainbow-colors
  '("#FF0000" "#FF7F00" "#FFFF00" "#00FF00" "#0000FF" "#4B0082" "#9400D3")
  "Rainbow colors for trail effect.")

(defvar-local ridiculous-coding--rainbow-index 0
  "Current position in rainbow cycle.")

(defun ridiculous-coding--next-rainbow-color ()
  "Get next color in rainbow cycle."
  (let ((color (nth ridiculous-coding--rainbow-index
                    ridiculous-coding--rainbow-colors)))
    (setq ridiculous-coding--rainbow-index
          (mod (1+ ridiculous-coding--rainbow-index)
               (length ridiculous-coding--rainbow-colors)))
    color))

(defun ridiculous-coding--rainbow-trail ()
  "Apply rainbow color to the just-typed character."
  (when (and ridiculous-coding-rainbow-enabled
             (> (point) (point-min)))
    (let* ((pos (1- (point)))
           (color (ridiculous-coding--next-rainbow-color))
           (ov (make-overlay pos (1+ pos))))
      (overlay-put ov 'priority 100)
      (overlay-put ov 'ridiculous t)
      (overlay-put ov 'face `(:foreground ,color :weight bold))
      (push ov ridiculous-coding--overlays)
      ;; Fade out over time with multiple steps
      (run-at-time 0.3 nil
                   (lambda (o)
                     (when (overlayp o)
                       (overlay-put o 'face `(:foreground ,color :weight normal))))
                   ov)
      (run-at-time 0.6 nil #'ridiculous-coding--remove-overlay ov))))

;; Floating spirits - characters drift upward
(defun ridiculous-coding--spawn-spirit (char)
  "Spawn CHAR as a spirit that floats upward."
  (when ridiculous-coding-spirits-enabled
    (let* ((start-pos (point))
           (col (current-column))
           (line (line-number-at-pos))
           (spirit-char (propertize char 'face
                                    `(:foreground "#88FFFF" :weight bold :height 1.2)))
           (frames 5)
           (frame-delay 0.06))
      ;; Animate upward by creating overlays on lines above
      (dotimes (i frames)
        (run-at-time (* i frame-delay) nil
                     (lambda (idx ch)
                       (save-excursion
                         (goto-char (point-min))
                         (forward-line (max 0 (- line idx 2)))
                         (move-to-column col t)
                         (let ((ov (make-overlay (point) (1+ (point)))))
                           (overlay-put ov 'priority 10000)
                           (overlay-put ov 'ridiculous t)
                           ;; Fade as it rises
                           (let* ((alpha (- 1.0 (/ (float idx) frames)))
                                  (gray (floor (* alpha 255))))
                             (overlay-put ov 'display
                                          (propertize ch 'face
                                                      `(:foreground
                                                        ,(format "#%02X%02X%02X"
                                                                 (floor (* alpha 136))
                                                                 (floor (* alpha 255))
                                                                 (floor (* alpha 255)))
                                                        :height ,(+ 1.0 (* 0.1 idx))))))
                           (push ov ridiculous-coding--overlays)
                           (run-at-time frame-delay nil
                                        #'ridiculous-coding--remove-overlay ov))))
                     i spirit-char)))))

;; Shockwave rings expanding outward
(defun ridiculous-coding--shockwave ()
  "Create expanding ring shockwave from point."
  (when ridiculous-coding-shockwave-enabled
    (let* ((center (point))
           (frames '(("·" . 0.0)
                     ("○" . 0.04)
                     ("◯" . 0.08)
                     ("◎" . 0.12)
                     ("●" . 0.16)))
           (colors '("#FFFFFF" "#FFFF88" "#FFAA44" "#FF4444" "#880000")))
      (cl-loop for (char . delay) in frames
               for color in colors
               for i from 0
               do (run-at-time delay nil
                               (lambda (c col pos)
                                 (when (and (>= pos (point-min))
                                            (< pos (point-max)))
                                   (let ((ov (make-overlay pos (min (1+ pos) (point-max)))))
                                     (overlay-put ov 'priority (- 10000 i))
                                     (overlay-put ov 'ridiculous t)
                                     (overlay-put ov 'display
                                                  (propertize c 'face
                                                              `(:foreground ,col :height 1.5)))
                                     (push ov ridiculous-coding--overlays)
                                     (run-at-time 0.05 nil
                                                  #'ridiculous-coding--remove-overlay ov))))
                               char color center)))))

;; Afterimage ghost effect
(defun ridiculous-coding--afterimage (char)
  "Create a ghostly afterimage of CHAR that fades."
  (when (and ridiculous-coding-afterimage-enabled
             (> (point) (point-min)))
    (let* ((pos (1- (point)))
           (ghost-colors '("#FFFFFF" "#CCCCCC" "#999999" "#666666" "#333333"))
           (delays '(0.0 0.05 0.1 0.15 0.2)))
      (cl-loop for color in ghost-colors
               for delay in delays
               do (run-at-time delay nil
                               (lambda (p c col)
                                 (when (and (>= p (point-min)) (< p (point-max)))
                                   (let ((ov (make-overlay p (1+ p))))
                                     (overlay-put ov 'priority 50)
                                     (overlay-put ov 'ridiculous t)
                                     (overlay-put ov 'after-string
                                                  (propertize c 'face
                                                              `(:foreground ,col)))
                                     (push ov ridiculous-coding--overlays)
                                     (run-at-time 0.05 nil
                                                  #'ridiculous-coding--remove-overlay ov))))
                               pos char color)))))

;; Key puff - show typed key as expanding, fading puff
(defconst ridiculous-coding--puff-colors
  '("#FF6B6B" "#FFE66D" "#4ECDC4" "#FF8C42" "#A855F7" "#22D3EE" "#FF69B4" "#00FF88")
  "Bright colors for key puff effect.")

(defun ridiculous-coding--key-puff (char)
  "Show CHAR as an expanding puff that scales up and fades out."
  (when (and ridiculous-coding-key-puff-enabled
             (not (string-match-p "[\n\t]" char)))
    (let* ((buf (current-buffer))
           (pos (max (1- (point)) (point-min)))
           (color (ridiculous-coding--random-element ridiculous-coding--puff-colors))
           (frames '((1.4 . "FF") (1.8 . "DD") (2.2 . "BB")
                     (2.6 . "88") (2.2 . "55") (1.8 . "33")))
           (frame-delay 0.045))
      ;; Defer to avoid interfering with self-insert
      (run-at-time 0 nil
                   (lambda ()
                     (dotimes (i (length frames))
                       (run-at-time (* i frame-delay) nil
                                    (lambda (frame-idx p b c col)
                                      (when (buffer-live-p b)
                                        (with-current-buffer b
                                          (when (and (>= p (point-min)) (<= p (point-max)))
                                            (let* ((frame-data (nth frame-idx frames))
                                                   (height (car frame-data))
                                                   (ov (make-overlay p (min (1+ p) (point-max)))))
                                              (overlay-put ov 'priority (+ 18000 (- 10 frame-idx)))
                                              (overlay-put ov 'ridiculous t)
                                              (overlay-put ov 'after-string
                                                           (propertize (upcase c) 'face
                                                                       `(:foreground ,col
                                                                         :height ,height
                                                                         :weight bold)))
                                              (push ov ridiculous-coding--overlays)
                                              (run-at-time frame-delay nil
                                                           #'ridiculous-coding--remove-overlay ov))))))
                                    i pos buf char color)))))))

;; Screen flash - pulse background on combos
(defun ridiculous-coding--flash (color)
  "Flash the screen with COLOR."
  (when ridiculous-coding-flash-enabled
    (let* ((win (selected-window))
           (buf (window-buffer win))
           (orig-bg (or (face-background 'default) "#000000"))
           (flash-face (make-symbol "flash-face")))
      ;; Create temporary face
      (face-spec-set flash-face `((t :background ,color)))
      ;; Apply flash overlay to whole visible region
      (let ((ov (make-overlay (window-start win) (window-end win))))
        (overlay-put ov 'priority 20000)
        (overlay-put ov 'ridiculous t)
        (overlay-put ov 'face `(:background ,color))
        (push ov ridiculous-coding--overlays)
        ;; Quick flash sequence
        (run-at-time 0.03 nil
                     (lambda (o)
                       (when (overlayp o)
                         (overlay-put o 'face `(:background ,(ridiculous-coding--blend-colors color orig-bg 0.5)))))
                     ov)
        (run-at-time 0.06 nil #'ridiculous-coding--remove-overlay ov)))))

(defun ridiculous-coding--blend-colors (c1 c2 ratio)
  "Blend C1 and C2 by RATIO (0.0 = c1, 1.0 = c2)."
  (let* ((rgb1 (color-name-to-rgb c1))
         (rgb2 (color-name-to-rgb c2)))
    (if (and rgb1 rgb2)
        (format "#%02X%02X%02X"
                (floor (* 255 (+ (* (nth 0 rgb1) (- 1 ratio)) (* (nth 0 rgb2) ratio))))
                (floor (* 255 (+ (* (nth 1 rgb1) (- 1 ratio)) (* (nth 1 rgb2) ratio))))
                (floor (* 255 (+ (* (nth 2 rgb1) (- 1 ratio)) (* (nth 2 rgb2) ratio)))))
      c1)))

;; MEGA combo effects
(defun ridiculous-coding--mega-combo ()
  "Unleash visual chaos for big combo milestones."
  (ridiculous-coding--flash "#FFFF00")
  (ridiculous-coding--shockwave)
  (dotimes (_ 3)
    (ridiculous-coding--spawn-spirit
     (ridiculous-coding--random-element '("★" "✦" "✧" "⚡" "💥" "🔥")))))

;;; ============================================================================
;;; Visual Effects: IMAGE ANIMATIONS (GUI only)
;;; ============================================================================

(defun ridiculous-coding--gui-p ()
  "Return t if running in GUI mode with image support."
  (and (display-graphic-p)
       ridiculous-coding-images-enabled
       (image-type-available-p 'png)))

(defun ridiculous-coding--load-sprite-sheet (filename)
  "Load sprite sheet FILENAME from images directory."
  (let ((path (expand-file-name filename ridiculous-coding-images-directory)))
    (when (file-exists-p path)
      path)))

(defun ridiculous-coding--extract-frame (sprite-path frame-width frame-height frame-index)
  "Extract a frame from sprite sheet at SPRITE-PATH.
FRAME-WIDTH and FRAME-HEIGHT are the dimensions of each frame.
FRAME-INDEX is which frame to extract (0-indexed, left to right)."
  (when sprite-path
    (let ((x-offset (* frame-index frame-width)))
      (create-image sprite-path 'png nil
                    :crop (list x-offset 0 frame-width frame-height)
                    :scale 0.5  ; Scale down for editor
                    :ascent 'center))))

(defun ridiculous-coding--animate-sprite (sprite-path frame-width frame-height
                                                       num-frames frame-delay)
  "Animate sprite sheet at point.
SPRITE-PATH is the image file.
FRAME-WIDTH/HEIGHT are frame dimensions.
NUM-FRAMES is total frame count.
FRAME-DELAY is seconds between frames."
  (when (and (ridiculous-coding--gui-p) sprite-path)
    (let ((buf (current-buffer))
          (pos (point)))
      (dotimes (i num-frames)
        (run-at-time (* i frame-delay) nil
                     (lambda (frame-idx p b)
                       (when (buffer-live-p b)
                         (with-current-buffer b
                           (when (and (>= p (point-min))
                                      (< p (point-max)))
                             (let* ((img (ridiculous-coding--extract-frame
                                          sprite-path frame-width frame-height frame-idx))
                                    (ov (make-overlay p (1+ p))))
                               (when img
                                 (overlay-put ov 'priority 15000)
                                 (overlay-put ov 'ridiculous t)
                                 (overlay-put ov 'after-string (propertize " " 'display img))
                                 (push ov ridiculous-coding--overlays)
                                 (run-at-time frame-delay nil
                                              #'ridiculous-coding--remove-overlay ov)))))))
                     i pos buf)))))

(defun ridiculous-coding--boom-animation ()
  "Play the boom explosion animation at point."
  (if (ridiculous-coding--gui-p)
      (let ((sprite (ridiculous-coding--load-sprite-sheet "boom.png")))
        (when sprite
          ;; boom.png is 768x256, 6 frames of 128x256
          (ridiculous-coding--animate-sprite sprite 128 256 6 0.05)))
    ;; Fallback to text explosion
    (ridiculous-coding--big-explosion)))

(defun ridiculous-coding--blip-animation ()
  "Play the blip animation at point."
  (if (ridiculous-coding--gui-p)
      (let ((sprite (ridiculous-coding--load-sprite-sheet "blip.png")))
        (when sprite
          ;; blip.png is 256x32, 8 frames of 32x32
          (ridiculous-coding--animate-sprite sprite 32 32 8 0.03)))
    ;; Fallback to text explosion
    (ridiculous-coding--explosion-at-point)))

(defun ridiculous-coding--newline-animation ()
  "Play the newline animation."
  (if (ridiculous-coding--gui-p)
      (let ((sprite (ridiculous-coding--load-sprite-sheet "newline.png")))
        (when sprite
          ;; newline.png is 320x64, 5 frames of 64x64
          (ridiculous-coding--animate-sprite sprite 64 64 5 0.04)))
    ;; Fallback
    (ridiculous-coding--shockwave)))

;;; ============================================================================
;;; Combo System
;;; ============================================================================

(defun ridiculous-coding--update-combo ()
  "Increment combo counter and handle combo events."
  (when ridiculous-coding-combo-enabled
    ;; Cancel existing timeout
    (when ridiculous-coding--combo-timer
      (cancel-timer ridiculous-coding--combo-timer))
    ;; Increment
    (cl-incf ridiculous-coding--combo-count)
    ;; Check for combo threshold
    (when (and (> ridiculous-coding--combo-count 0)
               (= (mod ridiculous-coding--combo-count
                       ridiculous-coding-combo-threshold) 0))
      (ridiculous-coding--combo-bonus))
    ;; Set timeout
    (setq ridiculous-coding--combo-timer
          (run-at-time ridiculous-coding-combo-timeout nil
                       #'ridiculous-coding--reset-combo))))

(defun ridiculous-coding--reset-combo ()
  "Reset the combo counter."
  (setq ridiculous-coding--combo-count 0)
  (when ridiculous-coding--combo-timer
    (cancel-timer ridiculous-coding--combo-timer)
    (setq ridiculous-coding--combo-timer nil)))

(defun ridiculous-coding--combo-bonus ()
  "Trigger bonus effects for hitting combo threshold."
  (let ((count ridiculous-coding--combo-count))
    ;; Defer all effects to run after self-insert completes
    (run-at-time 0 nil
                 (lambda ()
                   (ridiculous-coding--mega-combo)
                   (ridiculous-coding--boom-animation)
                   (ridiculous-coding--big-shake)
                   (ridiculous-coding--play-sound 'combo)
                   (message "🔥 COMBO x%d! 🔥" count)))))

;;; ============================================================================
;;; Visual Effects: REGION SELECTION
;;; ============================================================================

(defvar-local ridiculous-coding--region-overlays nil
  "Overlays for region selection effects.")

(defvar-local ridiculous-coding--region-pulse-timer nil
  "Timer for region pulse animation.")

(defconst ridiculous-coding--selection-colors
  '("#FF6B6B" "#FFE66D" "#4ECDC4" "#FF8C42" "#A855F7" "#22D3EE" "#FF69B4")
  "Colors for selection effects.")

(defun ridiculous-coding--region-sparkle (start end)
  "Spawn sparkles along the region from START to END."
  (let* ((len (min (- end start) 50))  ; Cap at 50 sparkles
         (sparkle-chars '("✦" "✧" "★" "☆" "✨" "·" "°"))
         (step (max 1 (/ (- end start) len))))
    (dotimes (i len)
      (let* ((pos (+ start (* i step)))
             (char (ridiculous-coding--random-element sparkle-chars))
             (color (ridiculous-coding--random-element ridiculous-coding--selection-colors))
             (delay (* i 0.02)))
        (run-at-time delay nil
                     (lambda (p c col)
                       (when (and (>= p (point-min)) (< p (point-max)))
                         (let ((ov (make-overlay p (min (1+ p) (point-max)))))
                           (overlay-put ov 'priority 8000)
                           (overlay-put ov 'ridiculous t)
                           (overlay-put ov 'after-string
                                        (propertize c 'face `(:foreground ,col :height 0.8)))
                           (push ov ridiculous-coding--overlays)
                           (run-at-time 0.15 nil #'ridiculous-coding--remove-overlay ov))))
                     pos char color)))))

(defun ridiculous-coding--region-glow (start end)
  "Create a glowing border effect around region from START to END."
  (let* ((ov (make-overlay start end))
         ;; Pairs of (border-color . background-color) - backgrounds are muted versions
         (color-pairs '(("#FFFF00" . "#3D3D00")
                        ("#FFDD00" . "#3D3500")
                        ("#FFBB00" . "#3D2D00")
                        ("#FF9900" . "#3D2400")
                        ("#FF7700" . "#3D1C00"))))
    (overlay-put ov 'priority 7000)
    (overlay-put ov 'ridiculous t)
    (overlay-put ov 'face `(:background "#3D3D00" :box (:line-width 2 :color "#FFFF00")))
    (push ov ridiculous-coding--region-overlays)
    ;; Pulse the glow
    (let ((pulse-idx 0))
      (setq ridiculous-coding--region-pulse-timer
            (run-at-time 0 0.1
                         (lambda ()
                           (when (and (overlayp ov) (overlay-buffer ov))
                             (let* ((pair (nth (mod pulse-idx (length color-pairs)) color-pairs))
                                    (border-color (car pair))
                                    (bg-color (cdr pair)))
                               (overlay-put ov 'face
                                            `(:background ,bg-color
                                              :box (:line-width 2 :color ,border-color)))
                               (setq pulse-idx (1+ pulse-idx))))))))))

(defun ridiculous-coding--cleanup-region-effects ()
  "Clean up region-specific overlays and timers."
  (when ridiculous-coding--region-pulse-timer
    (cancel-timer ridiculous-coding--region-pulse-timer)
    (setq ridiculous-coding--region-pulse-timer nil))
  (mapc #'delete-overlay ridiculous-coding--region-overlays)
  (setq ridiculous-coding--region-overlays nil))

(defvar-local ridiculous-coding--region-active-p nil
  "Track whether region was active last command, for edge detection.")

(defvar-local ridiculous-coding--region-bounds nil
  "Track last region bounds (start . end) to detect changes.")

(defun ridiculous-coding--check-region ()
  "Check region state after each command, trigger effects on activation/change."
  (let ((now-active (and (region-active-p) (use-region-p))))
    (cond
     ;; Region just became active
     ((and now-active (not ridiculous-coding--region-active-p))
      (setq ridiculous-coding--region-active-p t)
      (ridiculous-coding--region-activated))
     ;; Region just deactivated
     ((and (not now-active) ridiculous-coding--region-active-p)
      (setq ridiculous-coding--region-active-p nil)
      (setq ridiculous-coding--region-bounds nil)
      (ridiculous-coding--cleanup-region-effects))
     ;; Region still active - check if bounds changed significantly
     (now-active
      (let* ((start (region-beginning))
             (end (region-end))
             (old-bounds ridiculous-coding--region-bounds)
             (size-change (when old-bounds
                            (abs (- (- end start)
                                    (- (cdr old-bounds) (car old-bounds)))))))
        ;; Re-trigger effects if region grew by 10+ chars
        (when (and size-change (>= size-change 10))
          (ridiculous-coding--region-activated))
        (setq ridiculous-coding--region-bounds (cons start end)))))))

(defun ridiculous-coding--region-activated ()
  "Handle region activation - selection started or significantly changed."
  (when (and ridiculous-coding-particles-enabled
             (region-active-p)
             (use-region-p))
    (ridiculous-coding--cleanup-region-effects)
    (let ((start (region-beginning))
          (end (region-end)))
      (setq ridiculous-coding--region-bounds (cons start end))
      ;; Sparkle cascade along selection
      (ridiculous-coding--region-sparkle start end)
      ;; Glowing border
      (ridiculous-coding--region-glow start end)
      ;; Small satisfying sound
      (when (ridiculous-coding--maybe-p 0.3)
        (ridiculous-coding--play-sound 'typing)))))

;;; ============================================================================
;;; Visual Effects: DELETION CARNAGE
;;; ============================================================================

(defconst ridiculous-coding--skull-chars
  '("💀" "☠" "✖" "✗" "×" "†" "‡")
  "Characters for deletion effects.")

(defconst ridiculous-coding--fire-chars
  '("🔥" "💥" "✦" "⚡" "★" "*" "#")
  "Fire/destruction characters.")

(defun ridiculous-coding--deletion-skull (pos)
  "Spawn a skull at POS that fades away."
  (when (and (>= pos (point-min)) (<= pos (point-max)))
    (let* ((skull (ridiculous-coding--random-element ridiculous-coding--skull-chars))
           (ov (make-overlay pos (min (1+ pos) (point-max)))))
      (overlay-put ov 'priority 9500)
      (overlay-put ov 'ridiculous t)
      (overlay-put ov 'after-string
                   (propertize skull 'face '(:foreground "#FF4444" :height 1.3)))
      (push ov ridiculous-coding--overlays)
      ;; Fade sequence
      (run-at-time 0.1 nil
                   (lambda (o)
                     (when (overlayp o)
                       (overlay-put o 'after-string
                                    (propertize skull 'face '(:foreground "#CC3333" :height 1.1)))))
                   ov)
      (run-at-time 0.2 nil #'ridiculous-coding--remove-overlay ov))))

(defun ridiculous-coding--deletion-fire-trail (pos count)
  "Spawn COUNT fire particles spreading from POS."
  (dotimes (i count)
    (let* ((offset (- (random 9) 4))
           (fire-pos (+ pos offset))
           (char (ridiculous-coding--random-element ridiculous-coding--fire-chars))
           (color (ridiculous-coding--random-element
                   '("#FF6600" "#FF4400" "#FF2200" "#FF0000" "#CC0000")))
           (delay (* i 0.015)))
      (run-at-time delay nil
                   (lambda (p c col)
                     (when (and (>= p (point-min)) (<= p (point-max)))
                       (let ((ov (make-overlay p (min (1+ p) (point-max)))))
                         (overlay-put ov 'priority (+ 9000 (random 100)))
                         (overlay-put ov 'ridiculous t)
                         (overlay-put ov 'display (propertize c 'face `(:foreground ,col)))
                         (push ov ridiculous-coding--overlays)
                         (run-at-time (+ 0.05 (* (random 5) 0.02)) nil
                                      #'ridiculous-coding--remove-overlay ov))))
                   fire-pos char color))))

(defun ridiculous-coding--vaporize-region (start end)
  "Epic vaporization effect when deleting a region."
  ;; Screen flash - red for destruction
  (ridiculous-coding--flash "#FF220044")
  ;; Big shake
  (ridiculous-coding--big-shake)
  ;; Fire explosion at the deletion point
  (ridiculous-coding--deletion-fire-trail start (min 15 (- end start)))
  ;; Skulls at start and end
  (ridiculous-coding--deletion-skull start)
  (when (> (- end start) 5)
    (ridiculous-coding--deletion-skull (min (1- end) (1- (point-max)))))
  ;; Rising spirits of the deleted text
  (when ridiculous-coding-spirits-enabled
    (let ((sample-chars (buffer-substring-no-properties
                         start (min end (+ start 3)))))
      (dotimes (i (min 3 (length sample-chars)))
        (run-at-time (* i 0.1) nil
                     (lambda (ch)
                       (ridiculous-coding--spawn-spirit
                        (propertize (char-to-string ch)
                                    'face '(:foreground "#FF8888"))))
                     (aref sample-chars i)))))
  ;; Sound
  (ridiculous-coding--play-sound 'delete))

(defun ridiculous-coding--small-delete-effect ()
  "Effect for single character deletion."
  (let ((pos (point)))
    ;; Small spark
    (when (ridiculous-coding--maybe-p 0.5)
      (ridiculous-coding--deletion-skull pos))
    ;; Tiny fire burst
    (ridiculous-coding--deletion-fire-trail pos (+ 2 (random 3)))
    ;; Occasional shake
    (when (ridiculous-coding--maybe-p 0.2)
      (ridiculous-coding--small-shake))))

;;; ============================================================================
;;; Event Handlers
;;; ============================================================================

(defun ridiculous-coding--maybe-p (probability)
  "Return t with given PROBABILITY (0.0-1.0)."
  (< (cl-random 1.0) probability))

(defun ridiculous-coding--on-typing ()
  "Handle typing event."
  (ridiculous-coding--update-combo)
  (let* ((char (char-to-string last-command-event))
         (combo ridiculous-coding--combo-count)
         (intensity (+ ridiculous-coding-intensity
                       (* 0.01 (min combo 20))))
         (is-newline (eq last-command-event ?\n))
         (demo ridiculous-coding-demo-mode))
    ;; Special handling for newlines
    (when is-newline
      (ridiculous-coding--newline-animation))
    ;; Key puff - the star of the show
    (ridiculous-coding--key-puff char)
    ;; Rainbow trail - ALWAYS on when enabled (it's the baseline pop)
    (ridiculous-coding--rainbow-trail)
    ;; Afterimage echo
    (when (or demo (ridiculous-coding--maybe-p 0.7))
      (ridiculous-coding--afterimage char))
    ;; Explosions/blips
    (when (or demo (ridiculous-coding--maybe-p intensity))
      (if (ridiculous-coding--gui-p)
          (ridiculous-coding--blip-animation)
        (ridiculous-coding--explosion-at-point))
      (when (or demo (ridiculous-coding--maybe-p 0.5))
        (ridiculous-coding--small-shake))
      (when (or demo (ridiculous-coding--maybe-p 0.3))
        (ridiculous-coding--play-sound 'typing)))
    ;; Spirits - in demo mode, every 3rd keystroke
    (when (or (and demo (= (mod combo 3) 0))
              (and (> combo 5) (ridiculous-coding--maybe-p 0.15)))
      (ridiculous-coding--spawn-spirit char))
    ;; Shockwaves - in demo mode, every 5th keystroke
    (when (or (and demo (= (mod combo 5) 0))
              (and (> combo 15) (ridiculous-coding--maybe-p 0.1)))
      (ridiculous-coding--shockwave))))

(defun ridiculous-coding--on-delete (deleted-length)
  "Handle deletion event. DELETED-LENGTH is how many chars were deleted."
  (if (> deleted-length 3)
      ;; Big deletion - region kill, word delete, etc.
      (ridiculous-coding--vaporize-region (point) (+ (point) deleted-length))
    ;; Single char deletion - still make it pop
    (ridiculous-coding--small-delete-effect)))

(defun ridiculous-coding--on-save ()
  "Handle save event - always dramatic."
  (ridiculous-coding--big-explosion)
  (ridiculous-coding--big-shake)
  (ridiculous-coding--play-sound 'save)
  (message "SAVED!"))

;;; ============================================================================
;;; Hooks
;;; ============================================================================

(defun ridiculous-coding--post-self-insert ()
  "Hook for post-self-insert-hook."
  (ridiculous-coding--on-typing))

(defun ridiculous-coding--after-change (beg end len)
  "Hook for after-change-functions. BEG END LEN are change params."
  ;; Deletion happened if len > 0 and no new text inserted
  (when (and (> len 0) (= beg end))
    (ridiculous-coding--on-delete len)))

(defun ridiculous-coding--after-save ()
  "Hook for after-save-hook."
  (ridiculous-coding--on-save))

;;; ============================================================================
;;; Minor Mode
;;; ============================================================================

;;;###autoload
(define-minor-mode ridiculous-coding-mode
  "Toggle ridiculous coding effects.
Makes your coding experience absurdly dramatic with explosions,
screen shake, sounds, and combo counters."
  :lighter " BOOM"
  :group 'ridiculous-coding
  (if ridiculous-coding-mode
      (progn
        (add-hook 'post-self-insert-hook
                  #'ridiculous-coding--post-self-insert nil t)
        (add-hook 'after-change-functions
                  #'ridiculous-coding--after-change nil t)
        (add-hook 'after-save-hook
                  #'ridiculous-coding--after-save nil t)
        (add-hook 'kill-buffer-hook
                  #'ridiculous-coding--kill-buffer-cleanup nil t)
        (add-hook 'post-command-hook
                  #'ridiculous-coding--check-region nil t))
    ;; Cleanup
    (remove-hook 'post-self-insert-hook
                 #'ridiculous-coding--post-self-insert t)
    (remove-hook 'after-change-functions
                 #'ridiculous-coding--after-change t)
    (remove-hook 'after-save-hook
                 #'ridiculous-coding--after-save t)
    (remove-hook 'kill-buffer-hook
                 #'ridiculous-coding--kill-buffer-cleanup t)
    (remove-hook 'post-command-hook
                 #'ridiculous-coding--check-region t)
    (ridiculous-coding--cleanup-overlays)
    (ridiculous-coding--cleanup-region-effects)
    (ridiculous-coding--reset-combo)))

;;;###autoload
(define-globalized-minor-mode global-ridiculous-coding-mode
  ridiculous-coding-mode
  (lambda ()
    (when (derived-mode-p 'prog-mode 'text-mode)
      (ridiculous-coding-mode 1))))

;;; ============================================================================
;;; Interactive Commands
;;; ============================================================================

(defun ridiculous-coding-test-explosion ()
  "Test the explosion effect."
  (interactive)
  (ridiculous-coding--big-explosion))

(defun ridiculous-coding-test-shake ()
  "Test the screen shake effect."
  (interactive)
  (ridiculous-coding--big-shake))

(defun ridiculous-coding-test-sound (category)
  "Test playing a sound from CATEGORY."
  (interactive
   (list (intern (completing-read "Category: "
                                  '("typing" "delete" "save" "combo")))))
  (ridiculous-coding--play-sound category))

(defun ridiculous-coding-set-intensity (level)
  "Set intensity to LEVEL (low, medium, high, insane)."
  (interactive
   (list (intern (completing-read "Intensity: "
                                  '("low" "medium" "high" "insane")))))
  (setq ridiculous-coding-intensity
        (pcase level
          ('low 0.05)
          ('medium 0.15)
          ('high 0.3)
          ('insane 0.6)))
  (message "Ridiculous intensity: %s (%.0f%%)" level
           (* 100 ridiculous-coding-intensity)))

(defun ridiculous-coding-test-rainbow ()
  "Test rainbow trail effect."
  (interactive)
  (dotimes (_ 20)
    (ridiculous-coding--rainbow-trail)
    (forward-char 1)))

(defun ridiculous-coding-test-spirit ()
  "Test spirit floating effect."
  (interactive)
  (ridiculous-coding--spawn-spirit "★"))

(defun ridiculous-coding-test-shockwave ()
  "Test shockwave effect."
  (interactive)
  (ridiculous-coding--shockwave))

(defun ridiculous-coding-test-flash ()
  "Test screen flash effect."
  (interactive)
  (ridiculous-coding--flash "#FF4444"))

(defun ridiculous-coding-test-mega ()
  "Test mega combo effect (all the things)."
  (interactive)
  (ridiculous-coding--mega-combo)
  (ridiculous-coding--big-explosion)
  (ridiculous-coding--big-shake)
  (message "🔥 MEGA TEST! 🔥"))

(defun ridiculous-coding-test-all ()
  "Test all effects in sequence."
  (interactive)
  (ridiculous-coding--rainbow-trail)
  (run-at-time 0.3 nil #'ridiculous-coding--explosion-at-point)
  (run-at-time 0.5 nil (lambda () (ridiculous-coding--spawn-spirit "✦")))
  (run-at-time 0.8 nil #'ridiculous-coding--shockwave)
  (run-at-time 1.0 nil (lambda () (ridiculous-coding--flash "#FFFF00")))
  (run-at-time 1.2 nil #'ridiculous-coding--big-shake)
  (message "Testing all effects..."))

(defun ridiculous-coding-test-blip ()
  "Test the blip image animation."
  (interactive)
  (if (ridiculous-coding--gui-p)
      (ridiculous-coding--blip-animation)
    (message "Images only work in GUI mode")))

(defun ridiculous-coding-test-boom ()
  "Test the boom image animation."
  (interactive)
  (if (ridiculous-coding--gui-p)
      (ridiculous-coding--boom-animation)
    (message "Images only work in GUI mode")))

(defun ridiculous-coding-test-newline ()
  "Test the newline image animation."
  (interactive)
  (if (ridiculous-coding--gui-p)
      (ridiculous-coding--newline-animation)
    (message "Images only work in GUI mode")))

(defun ridiculous-coding-toggle-images ()
  "Toggle image animations on/off."
  (interactive)
  (setq ridiculous-coding-images-enabled (not ridiculous-coding-images-enabled))
  (message "Image animations: %s" (if ridiculous-coding-images-enabled "ON" "OFF")))

(defun ridiculous-coding-test-deletion ()
  "Test deletion effects (small and large)."
  (interactive)
  (message "Small delete effect:")
  (ridiculous-coding--small-delete-effect)
  (run-at-time 0.5 nil
               (lambda ()
                 (message "Large delete effect (vaporize):")
                 (ridiculous-coding--vaporize-region (point) (min (+ (point) 10) (point-max))))))

(defun ridiculous-coding-test-region ()
  "Test region selection effects at current point."
  (interactive)
  (let ((start (point))
        (end (min (+ (point) 30) (point-max))))
    (ridiculous-coding--region-sparkle start end)
    (message "Region sparkle effect triggered")))

(defun ridiculous-coding-test-key-puff ()
  "Test key puff effect with a few characters."
  (interactive)
  (let ((chars '("A" "B" "C" "X" "Y" "Z")))
    (dotimes (i (length chars))
      (run-at-time (* i 0.15) nil
                   (lambda (c)
                     (ridiculous-coding--key-puff c))
                   (nth i chars)))))   
                                       
(provide 'ridiculous-coding)           
;;; ridiculous-coding.el ends here     
; this is a test. why isn't it working????
