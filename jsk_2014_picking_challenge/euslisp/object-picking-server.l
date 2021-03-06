#!/usr/bin/env roseus

(load "package://baxtereus/baxter-interface.l")
(load "package://jsk_2014_picking_challenge/euslisp/pod-lowres.l")
(load "package://jsk_2014_picking_challenge/euslisp/order-bin.l")
(load "package://jsk_2014_picking_challenge/euslisp/gripper-control.l")

(ros::load-ros-manifest "roseus")
(ros::load-ros-manifest "jsk_2014_picking_challenge")

(defclass object-picking-actionlib-server
  :super propertied-object
  :slots ((action :forward (:worker)
           step-list counter)))
(defmethod object-picking-actionlib-server
  (:init
    ()
    (setq step-list (list 60 60 60 60 60 60))
    (setq counter 0)
    (baxter-init)
    (send *baxter* :locate #f(0 0 950) :world)
    (send *baxter* :angle-vector (send *ri* :state :potentio-vector))
    (pod-init)
    (orderbin-init)
    (objects (list *baxter* *pod* *orderbin*))
    (setq action (instance ros::simple-action-server :init
                           "/object_picking" jsk_2014_picking_challenge::ObjectPickingAction
                           :execute-cb `(lambda (server goal) (send ,self :execute-cb server goal)))))
  (:execute-cb
    (server goal)
    (let* ((l/r (send goal :goal :limb))
           (on/off (send goal :goal :state)) ;; if you want to return items, state must be "false"
	   (random-y (list 0 0 0))
           seq picking-coords msg)
      ;; l/r validataion
      (cond ((string-equal l/r "left") (setq l/r ':larm))
            ((string-equal l/r "right") (setq l/r ':rarm))
            (t (progn
                 (push "invalid_l/r" seq)
                 (setq msg (send server :result :sequence (nreverse seq)))
                 (send server :set-aborted msg)
                 (return-from :execute-cb nil))))
      ;; picking pose
      (push "goint to pick" seq)
      (ros::ros-info (format nil "[object_picking] going to pick object"))
      (setq avs nil)
      (push (send *baxter* :angle-vector (send *ri* :state :potentio-vector)) avs)
      (push (send *baxter* l/r :move-end-pos #f(0 0 30) :world :revert-if-fail nil) avs)
      (if on/off
        (push (send *baxter* l/r :move-end-pos #f(260 0 0) :world :revert-if-fail nil) avs)
        (push (send *baxter* l/r :move-end-pos #f(300 0 0) :world :revert-if-fail nil) avs))
      (push (send *baxter* l/r :move-end-pos (float-vector 0 (elt random-y (random (length random-y))) 0) :world :revert-if-fail nil) avs)
      ;;(push (send *baxter* l/r :move-end-pos (float-vector 0 (elt step-list counter) 0) :world :revert-if-fail nil) avs)
      ;;(incf counter)

      (push (send *baxter* l/r :move-end-pos #f(0 0 -75) :world :revert-if-fail nil) avs)
      (dolist (av (reverse avs))
        (send *ri* :angle-vector av 1000) (send *ri* :wait-interpolation))
      (send *irtviewer* :draw-objects)
      ;; go/stop grasp
      (push "go/stop grasp" seq)
      (ros::ros-info (format nil "[object_picking] cleaner ~A" (if on/off "ON" "OFF")))
      (send *ri* (if on/off :go-grasp :stop-grasp))
      ;; return to original pose
      (push "returning to original pose" seq)
      (ros::ros-info (format nil "[object_picking] returning to original pose."))
      (when on/off
        (setq avs (reverse avs))
        (pop avs)
        (push (send *baxter* :angle-vector (pop avs)) avs)
        (push (send *baxter* l/r :move-end-pos #f(-60 0 0) :world :revert-if-fail nil) avs)
        (setq avs (reverse avs)))
      (dolist (av avs) (send *ri* :angle-vector av 1000) (send *ri* :wait-interpolation))
      ; (send *ri* :angle-vector-sequence avs (make-list (length avs) :initial-element 5000))
      (send *ri* :wait-interpolation)
      (send *irtviewer* :draw-objects)
      ;; set result
      (setq msg (send server :result :sequence (nreverse seq)))
      (send server :set-succeeded msg)
      ))
  ;(:spin-once () (send self :worker) (send action :spin-once))
  ;(:spin () (do-until-key (send self :spin-once) (ros::sleep)))
  )

(ros::roseus "object_picking")
(ros::rate 500)
(setq s (instance object-picking-actionlib-server :init))
(setq r (ros::rate 10))
(do-until-key (ros::ok)
  (send *ri* :spin-once) ;; (ros::spin-once "baxter_interface")
  (send s :worker)
  (ros::spin-once)
  (ros::sleep))
