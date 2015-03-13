#!/usr/bin/env roseus
(ros::load-ros-manifest "roseus")
(ros::roseus "start_grasp_override")
(ros::advertise "on_off_gripper" std_msgs::Bool 1)
(ros::rate 10)

(defmethod baxter-interface
  (:go-grasp ()
   (ros::ros-info (format nil "cleaner ON"))
   (setq msg (instance std_msgs::Bool :init))
   (send msg :data t)
   (ros::publish "on_off_gripper" msg)
   (ros::sleep))
  (:stop-grasp ()
   (ros::ros-info (format nil "cleaner OFF"))
   (setq msg (instance std_msgs::Bool :init))
   (send msg :data nil)
   (ros::publish "on_off_gripper" msg)
   (ros::sleep)
  ))