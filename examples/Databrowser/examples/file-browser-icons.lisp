;; Copyright (2004) Sandia Corporation. Under the terms of Contract DE-AC04-94AL85000 with
;; Sandia Corporation, the U.S. Government retains certain rights in this software.

;; This software is governed by the terms
;; of the Lisp Lesser GNU Public License
;; (http://opensource.franz.com/preamble.html),
;; known as the LLGPL.

;; This software is available at
;; http://aisl.sandia.gov/source/

;;; file-browser.lisp
;;; An example of using the carbon databrowser.

; This puts up a browser window that's vaguely reminiscent of the Finder list view
;  in OSX. Shows the names of files in a folder and uses a checkbox to indicate whether the
;  item is visible to the Finder. 
; It's also vaguely reminiscent of dired under Emacs, but not as powerful. Still,
;  it's a decent demonstration of the databrowser.
; See view-key-event-handler method below for some handy keyboard shortcuts.

; CAPABILITIES
;  You can select a file, and columns hilite and re-sort when you click their header.
;  You can drag widths of the columns to what they need to be.
;  You can drag columns to reorder them.
;  Cmd-uparrow goes to parent directory.
;  Right-arrow opens a container; left-arrow closes it.
;  Columns re-sort when you click on them.
;  And 'hovering windoid' (what Cocoa calls 'help') pops up
;   when you hold mouse over an item that's not completely displayable in a column,
;   such as a too-long filename that normally displays with an ellipsis ...
;  Hit return or double click on a filename to open it in Fred. If you do this with
;   a file that's too big to open in Fred, and error is thrown. If you do this with
;   a file that's longer than 2^31, it appears with a negative length, and it just
;   beeps at you.
;  Typing first few characters of a thing's name selects it.
;  Doing Edit>Copy from a row copies the selected pathname(s) onto the clipboard.

; LIMITATIONS
;  This will only work in MCL 4.4b4 (carbon) or later. Preferably later.
;    Sorry about that, but there's no fix possible.
;  It looks a lot better in OSX than in OS9 or Classic.
;  Visibility checkbox is not "live" so changing it doesn't do anything.
;  Can't rename a file in this window (would you really want to?).
;  We don't show an icon along with the filename yet.
;  When you have several levels of twist-downs open and you close the top one, they are all
;     closed when you reopen the top one. That is, the sub-containers don't remember their
;     open/closed status. This is unlike the Finder.

; HISTORY
; Wednesday July 7, 2004 SVS now can go all the way to the top. Removed truename call from redraw
;    because it's unnecessary and it messes up the title bar when we're at the top, because it
;    causes #P"" to default to "ccl:".

; TO DO
;  Make sure #'directory won't try to resolve aliases needlessly. DONE.
;  Put in some kind of indicator that indicates the thing is working, e.g. when you hit cmd-uparrow.
;  Filter to just show .lisp files and directories?
;  Rename? Delete? True dired functionality?
;  Make it possible to go all the way up to the "My Computer" level and see your partitions. DONE.
;  Show accurate information for files > 2^31 long.
;  Show other attributes of files that #_FSGetCatalogInfo can provide.
;  

(in-package :ccl)

(export '(make-file-browser))

(require :databrowser)
(require :autosize)
(require :iconref)

(defvar *dont-resolve-aliases* nil "True if you don't want any of the standard file inquiry functions
   to attempt to resolve aliases.")

; Probably should make these changes to l1-files at some point
#-:CCL-5.1
(let ((*warn-if-redefine-kernel* nil))
(defun %path-to-iopb (path pb &optional errchk (dont-resolve *dont-resolve-aliases*) no-file-info &aux (errno 0) len aliasp)
  (let* ((path (translate-logical-pathname (merge-pathnames path)))
         (dir (mac-directory-namestring-1 path))
          nam 
         (dirp (directory-pathname-p path)))
    (block nil      
      (setq nam (mac-file-namestring-1 path))
      (setq len (length nam))
      (multiple-value-setq (errno aliasp) 
        (%path-GetDirInfo dir pb errchk t))  ;; this failed
      (unless (%izerop errno) (return))
      (when (or (%i> len 255)
                (and (%izerop len)(not dirp)))
        (setq errno $bdnamerr)
        (return))
      (with-macptrs ((np (%get-ptr pb $ioFileName)))
        (%put-string np nam))
      (when (and (not dirp) (not no-file-info))
        (let ((dirid (%get-long pb $iodirid)))
          (%put-word pb 0 $ioFDirIndex) ; already put the name
          (setq errno (#_PBGetCatInfoSync pb))
          (%put-long pb dirid $iodirid)
          (unless (zerop errno) (return))
          (when (pb-alias-p pb)
            (setq aliasp t)
            (unless dont-resolve 
              (setq errno (pb-resolve-alias pb)))))))
    (when errchk (unless (%izerop errno)(signal-file-error errno path)))
    (values errno aliasp)))
)
    
(defclass file-browser-window (window)
  ())

(defclass file-browser (brw:collection-databrowser)
  ((directory-path :initarg :directory-path :initform nil :accessor directory-path)
   (last-char-down-time :initarg :last-char-down-time :initform 0 :accessor
                        last-char-down-time
                        :documentation "Bookkeeping for typing in names for selecting")
   (current-search-string :initarg :current-search-string :initform
                          (make-array   10 :element-type 'base-character :adjustable t :fill-pointer 0)
                          :accessor current-search-string
                          :documentation "String typed in so far for selecting")
   (some-selected :initarg :some-selected :initform nil :accessor some-selected
                  :documentation "Subset of items selected so far by typing"))
  )

; === Here are a few column functions that aren't already built in to MCL

(defun safe-file-create-date (pathname)
  (let ((*alias-resolution-policy* :none))
    (file-create-date pathname) ))

(defun safe-file-write-date (pathname)
  (let ((*alias-resolution-policy* :none))
     (file-write-date pathname) ))

(defun file-total-size (pathname)
  "Return total data + resource size of pathname. If NIL shows up in this
   column, it generally means it's an alias that cannot be resolved."
  (let ((*dont-resolve-aliases* t) ; so we'll see the size of the alias file itself
        (*alias-resolution-policy* :none)) ; preferred method for MCL 5.1
    (unless (directoryp pathname)
      (+ (file-resource-size pathname) (file-data-size pathname)))))
 
(defun kind (pathname)
  (multiple-value-bind (resolution aliasp directoryp) (resolve-alias-file-quietly pathname)
    (if resolution
      (if aliasp
        (if directoryp
          "Directory Alias"
          "Alias")
        (if directoryp "Directory" "File"))
      "Alias (offline)")))

#-:CCL-5.1
(defmethod thing-visiblep ((thing t))
  "Returns t if thing (a pathname or string) represents a file visible to the finder.
   This might not be completely accurate for all files, especially the 'special' files like
   __Move&Rename."
  (let ((pf nil))
    (rlet ((fsspec :fsspec)
           (fndrInfo :FInfo))
      (setf pf (probe-file thing))
      (unless pf (error "File not found: ~S" thing))
      (with-pstrs ((name (mac-namestring pf)))
        (#_FSMakeFSSpec 0 0 name fsspec))
      (#_FSpGetFInfo fsspec fndrInfo)
      (zerop (logand (pref fndrInfo finfo.fdFlags) #$fInvisible)))))

#+:CCL-5.1
(defmethod thing-visiblep ((thing t))
  (let ((*alias-resolution-policy* :none))
    (not (ccl::is-path-invisible thing))))

; See http://developer.apple.com/technotes/fl/fl_30.html
; and http://developer.apple.com/technotes/tn/tn1142.html
; Probably should add this to l1-files at some point
#-CCL-5.1
(defun resolve-alias-file-quietly (path &aux result)
  "Returns nil if path is to an alias that can't be resolved without user interaction.
   Otherwise returns 3 values:
           resolution (actual ultimate pathname pointed to by the alias, or just
                       the pathname if it was not an alias),
           t if path really _was_ an alias file,
           t if ultimate resolution is a directory.
   Note: this doesn't deal correctly with paths that have midpath aliases. It won't
   try to resolve them--it just returns nil. But the result of #'directory, for example,
   shouldn't ever return a midpath alias pathname anyway. Right?"
  (rlet ((path-spec :FSSpec)
         (targetIsFolder (:pointer :boolean))
         (wasAliased (:pointer :boolean)))
    (with-pstrs ((p-name (mac-namestring path)))
      (when (= (#_FSMakeFSSpec 0 0 p-name path-spec) #$noErr)
        (setf result (#_ResolveAliasFileWithMountFlags path-spec t targetIsFolder wasAliased #$kResolveAliasFileNoUI))
        (if (= result #$nsvErr)
          ; volume is offline
          nil
          ; volume is online 
          (values (ccl::%path-from-fsspec path-spec)
                  (ccl::pascal-true (%get-word wasAliased))
                  (ccl::pascal-true (%get-word targetIsFolder))))))))

#+CCL-5.1
(defun resolve-alias-file-quietly (path) ; simpler than above
  ; This could almost be a call to probe-file except for the extra two values we need. 
  ; (Probe-file also deals properly with midpath aliases, which this doesn't.)
  ; Even so, this _could_ be written strictly in terms of high-level primitives (no fsrefs) but it wouldn't be quite as efficient.
  "Returns nil if path is to an alias that can't be resolved without user interaction.
   Otherwise returns 3 values:
           resolution (actual ultimate pathname pointed to by the alias, or just
                       the pathname if it was not an alias),
           t if path really _was_ an alias file,
           t if ultimate resolution is a directory.
   Note: this doesn't deal correctly with paths that have midpath aliases. But the result of #'directory, for example,
   shouldn't ever return a midpath alias pathname anyway. Right?"
  (let ((*alias-resolution-policy* :none))
    (rlet ((fsref :fsref))
      (path-to-fsref path fsref) ; don't do any resolution yet
      (multiple-value-bind (was-alias was-folder) (ccl::fsref-is-alias-p fsref) ; this actually does resolution if it's easy
        (cond (was-alias
               (multiple-value-bind (folderp resolved) (resolve-alias-from-fsref-quiet fsref)
                 (when resolved ; it's online
                   (values (ccl::%path-from-fsref fsref)
                           was-alias
                           folderp))))
              (t (values path nil was-folder)))))))

; === Here are the methods we have to specialize
(defmethod brw:databrowser-item-containerp ((browser t) (path pathname))
  "Show a triangle if the thing is a directory."
  (multiple-value-bind (resolution aliasp directoryp) (resolve-alias-file-quietly path)
    (declare (ignore resolution))
    (and (not aliasp) ; gotta check this first
         directoryp)))

(defmethod brw:databrowser-item-children ((browser t) (path string))
  (brw:databrowser-item-children browser (pathname path)))

(defmethod brw:databrowser-item-children ((browser t) (path pathname))
  "Don't need to check if path is a directory, because this won't be called unless databrowser-item-containerp is true."
  (let ((*dont-resolve-aliases* t)
        (*alias-resolution-policy* :none)) ; preferred method for MCL 5.1
    (if (string-equal "" (namestring path))
      (directory "*:" :resolve-aliases nil :directory-pathnames t) ; at top so just show volumes
      (directory (merge-pathnames "*.*" path) :directories t :files t :resolve-aliases nil :directory-pathnames t))))

; for column view
(defmethod brw:databrowser-item-parent ((browser t) (path pathname))
  (let ((*alias-resolution-policy* :none))
    (if (directoryp path)
      (up-directory path)
      (pathname (directory-namestring path)))))

; IF YOU HAVE >1 DIRECTORY SELECTED AND DOUBLE-CLICK, BROWSER GETS CONFUSED TRYING TO SET ITSELF
;   TO ALL OF THEM. NEED TO FIX THIS. 
; BEST SOLUTION IS PROBABLY TO JUST NOTICE THE FIRST DIRECTORY SELECTED, ACT ON IT, AND IGNORE
;   THE REST. BUT IF THERE ARE FILES SELECTED TOO, THEY NEED TO BE ACTED ON FIRST, AS THEIR ROWIDS
;   WILL BE MEANINGLESS AFTER THE BROWSER'S DIRECTORY CHANGES.
(defmethod brw:databrowser-item-double-clicked ((browser file-browser) rowID)
  (flet ((colonify (pathname) ; Now writing this damn function for the forty-eighth time
           "Ensures that pathname ends with a colon. Always returns a string."
           (let ((stringy (namestring pathname)))
             (if (char= (schar stringy (1- (length stringy))) #\:)
               stringy
               (concatenate 'string stringy (string #\:))
               ))))
    (let ((pathname (brw:databrowser-row-object browser rowID)))
      (multiple-value-bind (resolution aliasp directoryp) (resolve-alias-file-quietly pathname)
        (declare (ignore aliasp))
        (cond (directoryp
               (unless (directory-pathname-p resolution)
                 (setf resolution (directoryp resolution)))
               (setf (directory-path browser) (pathname resolution))
               (brw:databrowser-reveal-row browser (brw::get-row-ID browser 0))
               (redraw browser))
              (resolution
               (if (>= (file-total-size resolution) 0) ; can't deal with 64-bit file lengths yet
                 (ed resolution)
                 (ed-beep)))
              (t (ed-beep)))))))

; End specialized methods

(defun pure-directoryp (pathname)
  (let ((*alias-resolution-policy* :none))
    (directoryp pathname)))

; Begin column drawing functions
(defun get-leaf-name (pathname)
  ;(pathname-name pathname) ; doesn't work for directories
  (multiple-value-bind (resolution aliasp directoryp) (resolve-alias-file-quietly pathname)
    (declare (ignore resolution))
    (let ((pathname2 pathname))
      (if (and (not aliasp) ; gotta check this first
               directoryp)
        ; following kludge wouldn't be necessary if #'directory with :directory-pathnames t
        ;  would d.t.r.t. with weird arguments like
        ;  #P"Mac OSX:Volumes:*" but alas, it doesn't. Trailing colon never appears.
        (progn (unless (directory-pathname-p pathname) ; magic kludge. directory-pathname-p detects
                 ;   #'directory's brain damage; #'directoryp normalizes the name.
                 (setf pathname2 (pure-directoryp pathname)))
               (car (last (pathname-directory (pathname pathname2)))))
        (mac-file-namestring pathname)))))

(defun get-leaf-icon (pathname) 
  (make-instance 'file-icon :pathname pathname))

(defun get-leaf-icon&name (pathname)
  (values
   (get-leaf-icon pathname)
   (get-leaf-name pathname)))

(defmethod redraw ((browser file-browser))
  (brw:databrowser-remove-all browser)
  (set-window-title (view-window browser)
                    (let ((name (directory-namestring (directory-path browser))))
                      (if (string-equal "" name)
                        (machine-instance)
                        name)))
  (brw:databrowser-add-items browser (brw:databrowser-item-children browser (directory-path browser))))

; This isn't exactly the same as how the Finder does it. In standard-file dialogs, for instance,
;   selection moves to the item nearest to the key you press, even if there is no exact match.
;   Here, we don't move at all unless there's an exact match.
; The selection is also sometimes unintuitive when typing the names of things contained within other things.
(defmethod find-thing-with-string ((me file-browser) char)
  (let ((now (rref *current-event* eventrecord.when))
        (selected-row nil))
    (flet ((match? (path)
             (let ((result (search (current-search-string me) (get-leaf-name path)
                     :test #'char-equal)))
               (eql result 0))))
      (when (>= (- now (last-char-down-time me)) (* 2 ; WAG
                                                    #-:carbon-compat (#_LMGetDoubleTime) #+:carbon-compat (#_GetDblTime)))
        (setf (fill-pointer (current-search-string me)) 0
              (some-selected me) nil
              ))
      (setf (last-char-down-time me) now)
      (vector-push-extend char (current-search-string me))
      ; some-selected is now a list of pathnames. Could just as well be a list of rowIDs. But
      ;   that would require a hashtable lookup _within_ the match? function, where this way
      ;   only requires one lookup at the end. This way is probably faster.
      (if (some-selected me)
        (setf (some-selected me) (remove-if-not #'match? (some-selected me)))
        (loop for path being the hash-keys of (brw::reverse-table (brw::object-table me))
              do
              (when (match? path)
                (push path (some-selected me)))))
      
      (setf selected-row
            (when (some-selected me)
              (gethash (first (some-selected me)) (brw::reverse-table (brw::object-table me)))))
      (when selected-row
        (brw:databrowser-reveal-row me selected-row)
        )
      )))

(defmethod up-directory ((current-directory string))
  (up-directory (pathname current-directory)))

(defmethod up-directory ((current-directory pathname))
  (let* ((pd (pathname-directory current-directory))
         (new-directory current-directory))
    (setf new-directory (pathname (directory-namestring (make-pathname :directory (butlast pd)))))
    new-directory))

(defmethod up-browser ((browser file-browser))
  "Takes browser up one level in file hierarchy"
  (let ((old-directory-path (directory-path browser)))
    (setf (directory-path browser)
          (up-directory (directory-path browser)))
    ; make sure we show the directory we came up from
    (redraw browser)
    (brw:databrowser-reveal-row browser (brw:databrowser-object-row browser old-directory-path))))

(defmethod view-key-event-handler ((browser file-browser) char)
  (if (command-key-p)
    (case char
      ((#\UpArrow) ; cmd-uparrow = go to parent
       (up-browser browser))
      
      ((#\r #\R) ; cmd-R = reveal in Finder
       (when (and (fboundp 'ccl::select-finder) (fboundp 'ccl::finder-reveal))
         (multiple-value-bind (selected-items count)
                              (brw:databrowser-selected-rows browser)
           (funcall 'ccl::select-finder)
           (dotimes (i (min 10 count)) ; if too many are selected, only do the first 10
             (funcall 'ccl::finder-reveal (brw:databrowser-row-object browser (elt selected-items i))))))))
    (case char
      ((#\newline)
       (let ((selected-items (brw:databrowser-selected-rows browser)))
         (brw:databrowser-item-double-clicked browser (car selected-items))
         ))
      (t
       (if (or (char-lessp char #\space)
               (char-lessp #\~ char) 
               )
         (call-next-method)
         (find-thing-with-string browser char))))))

(defun make-file-browser (&optional (directory-path "ccl:"))
  "Display files and folders in directory-path."
  (let* ((w (make-instance 'file-browser-window :view-size #@(700 450)))
         (browser 
          (make-instance 'file-browser
            :directory-path (translate-logical-pathname directory-path)
            :selection-type :disjoint
            :column-descriptors #((get-leaf-icon&name :title "Name" :justification :left :property-type :iconandtext)
                                  (safe-file-create-date :PROPERTY-TYPE :TIME :TITLE "Date Created")
                                  (safe-file-write-date :PROPERTY-TYPE :TIME :WITH-SECONDS t :TITLE "Date Modified")
                                  (file-total-size :TITLE "Size")
                                  kind ; let it default
                                  (thing-visiblep :PROPERTY-TYPE :CHECKBOX :TITLE "Visible")
                                  )
            :triangle-space t ; allocate room for disclosure triangles to appear in first column
            :view-nick-name 'file-browser-view
            :view-position #@(10 10)
            :view-size #@(680 400)
            :view-container w
            :draggable-columns t
            :VIEW-FONT ; optional
            '(11)      ; Use 11 pt font
            ;'("Baskerville" 12 :SRCOR :PLAIN (:COLOR-INDEX 0))
            ))
         (up-button
          (MAKE-DIALOG-ITEM
           'ccl::button-dialog-item-ar
           #@(13 418)
           #@(72 20)
           "Up"
           #'(lambda (me) (declare (ignore me)) (up-browser browser))
           :view-container w
           :VIEW-FONT
           '("Lucida Grande" 13 :SRCCOPY :PLAIN (:COLOR-INDEX 0))
           :DEFAULT-BUTTON
           NIL)
          ))
    (declare (ignore-if-unused up-button))
    
    ; here's where we insert the initial rows
    (redraw browser)
    (brw::set-sort-column browser (brw::first-column-id browser))
    ))

(eval-when (:load-toplevel :execute)
  (provide "FILE-BROWSER"))

; (make-file-browser (choose-directory-dialog :prompt "Please choose a directory"))

; (make-file-browser) 