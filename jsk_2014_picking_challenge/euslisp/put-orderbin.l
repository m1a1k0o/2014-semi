#!/usr/bin/env roseus

(load "package://baxtereus/baxter-interface.l")
(load "package://jsk_2014_picking_challenge/euslisp/pod-lowres.l")
(load "package://jsk_2014_picking_challenge/euslisp/order-bin.l")
(load "package://jsk_2014_picking_challenge/euslisp/gripper-control.l")

(ros::load-ros-manifest "jsk_2014_picking_challenge")

(defclass put-orderbin-cb-class
  :super propertied-object
  :slots ())
(defmethod put-orderbin-cb-class
  (:init
    ()
    (baxter-init)
    (send *baxter* :locate #f(0 0 950) :world)
    (send *baxter* :angle-vector (send *ri* :state :potentio-vector))
    (pod-init)
    (orderbin-init)
    (objects (list *baxter* *pod* *orderbin*))
    (ros::advertise-service "/semi/larm_put_orderbin" jsk_2014_picking_challenge::ReleaseItem #'send self :cb-larm)
    (ros::advertise-service "/semi/rarm_put_orderbin" jsk_2014_picking_challenge::ReleaseItem #'send self :cb-rarm)
    (ros::ros-info "[put_orderbin] initialized"))
  (:cb-larm (req) (send self :callback req :larm))
  (:cb-rarm (req) (send self :callback req :rarm))
  (:callback
    (req limb)
    (ros::ros-info "[put_orderbin] called")
    (let ((foldav-l #f(37.3096 -2.30713 -74.0698 146.667 99.5361 -3.66943 6.48193))
          (foldav-r #f(-48.8672 -10.437 80.6616 148.645 -80.9033 1.38428 -18.8745))
          (foldav-r-upper #f(7.80029 -1.12061 82.9248 141.438 -116.477 -6.48193 -8.10791))
          (foldav-l-upper #f(-24.1919 1.07666 -90.9009 131.572 -58.4912 -0.812988 54.7559))
          (untuckav-l #f(-5.0 -57.0 -68.0 111.0 38.0 59.0 0.0))
          (untuckav-r  #f(5.0 -57.0 68.0 111.0 -38.0 59.0 0.0)))
      ;; move object to orderbin
      (setq avs nil)
      (push (send *baxter* :angle-vector (send *ri* :state :potentio-vector)) avs)
      (case limb
        (:rarm (send *baxter* :rarm :angle-vector foldav-r-upper))
        (:larm (send *baxter* :larm :angle-vector foldav-l-upper)))
      (push (send *baxter* :angle-vector) avs)
      (send *baxter* :larm :angle-vector foldav-l)
      (send *baxter* :rarm :angle-vector foldav-r)
      (push (send *baxter* :angle-vector) avs)
      (if (equal limb :larm)
        (send *baxter* limb :angle-vector untuckav-l)
        (send *baxter* limb :angle-vector untuckav-r))
      (setq target (make-cascoords :pos (send *orderbin* :transform-vector #f(0 0 300))
                                   :rot #2f((-3.6e-06 0 -1) (0 1 0) (1 0 -3.6e-06))))
      (push (send *baxter* limb :inverse-kinematics target :rotation-axis :z :revert-if-fail nil) avs)
      (push (send *baxter* limb :move-end-pos #f(0 0 -250) :world :revert-if-fail nil) avs)
      (send *ri* :angle-vector-sequence (reverse avs) (make-list (length avs) :initial-element 1))
      (send *ri* :wait-interpolation)
      (send *irtviewer* :draw-objects)
      (send *ri* :stop-grasp)  ;; release object
      ;; follow back same trajectory
      (setq avs (reverse avs))  ;; to go backwards
      (pop avs)  ;; to end with fold pose
      (send *ri* :angle-vector-sequence (reverse avs) (make-list (length avs) :initial-element 1))
      (setq avs (reverse avs))  ;; to go backwards
      (send *ri* :wait-interpolation)
      (setq avs (reverse avs))  ;; to go backwards
      (send *irtviewer* :draw-objects)
      ;;return response
      (setq res (send req :response))
      (send res :succeeded t)
      res))
  )

(ros::roseus "put_orderbin")
(ros::rate 500)
(setq m (instance put-orderbin-cb-class :init))
(setq r (ros::rate 10))
(do-until-key (ros::ok)
  (send *ri* :spin-once) ;; (ros::spin-once "baxter_interface")
  (ros::spin-once)
  (ros::sleep))

