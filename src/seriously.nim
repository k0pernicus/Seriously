import asyncdispatch
import notifications/macosx
import os
import strutils
import times

const SOON_TIMING: int = 10

type
  ReminderStatus = enum
    Done, Soon, Running
  ## A Place consists to give a location to your reminder
  Place = object
    address: string ## The address of your reminder (number, street...)
    city: string ## The city, like Montreal or Toronto
    post: string ## The post code, like 59000 (France), H2A3K2 (Montreal, Canada)
    country: string ## The country (France, Canada, USA, etc...)
  ## An object to represent the reminder
  Reminder = object
    date: TimeInfo ## The data of the reminder
    message: string ## The reminder - a simple message to display
    place: Place ## The place to remind
    alert: bool ## A boolean to know if the reminder has to be display or no
    status: ReminderStatus

## The list of reminders
var g_reminders: seq[Reminder] = @[]

## A procedure to display error messages
proc display_warning(msg: string) =
  echo "/!\\ WARNING $1 /!\\".format(msg)

proc strToTime(msg: string): TimeInfo =
  parse(msg, "yyyy/MM/dd-HH:mm")

## Simple function to transform a string into a boolean
proc strToBool(msg: string): bool =
  case msg.toUpper():
    of "TRUE": true
    else: false

## Simple function to transform a string into a Place object
proc strToPlace(msg: string): Place =
  var local_address, local_city, local_post, local_country = ""
  let place_line = msg.split("-")
  
  if not place_line.len() >= 2:
    display_warning("Problem with place '$#'".format(msg))

  local_address = place_line[0]
  local_city = place_line[1]

  if place_line.len() > 2:
    if not (place_line[2] == ""):
      local_post = place_line[3]
    if not (place_line[3] == ""):
      local_country = place_line[4]

  result = Place(
    address: local_address,
    city: local_city,
    post: local_post,
    country: local_country,
  )

## Simple function to transform a string into a Reminder object
proc parseReminder(line: string): Reminder =
  let reminder_line = line.split(";")
  var local_date: TimeInfo
  var local_reminder = ""
  var local_place = Place()
  var local_alert = false
  
  if not reminder_line.len() >= 2:
    display_warning("Problem with line '$#'".format(line))

  local_date = strToTime(reminder_line[0])
  local_reminder = reminder_line[1] 
 
  if reminder_line.len() > 2:
    if not (reminder_line[2] == ""):
      local_place = strToPlace(reminder_line[2])
    if not (reminder_line[3] == ""):
      local_alert = strToBool(reminder_line[3])

  result = Reminder(
    date: local_date,
    message: local_reminder,
    place: local_place,
    alert: local_alert,
    status: ReminderStatus.Running
  )

## Scan the content of the file - this file is the configuration file which contains events
proc scanContentFile(contentFile: File) =
   for line in lines contentFile:
     g_reminders.add(parseReminder(line))

## Function to compare a deadline with the current time
proc compareTime(deadline: Time): ReminderStatus =
  let current_time = getTime()
  case deadline - current_time:
    of low(int64)..0: ReminderStatus.Done
    of 1..SOON_TIMING*60: ReminderStatus.Soon
    else: ReminderStatus.Running

proc `$` (reminder: Reminder): string =
  result = "* $1 - $2: $3".format(reminder.date, reminder.message, reminder.status)

proc displayNotification(reminder: Reminder) =
  var center = newNotificationCenter()
  waitFor center.show($reminder.status, reminder.message)

when isMainModule:
  let file = open("./test/test.txt", FileMode.fmRead, 1024)
  scanContentFile(file)
  while true:
    # 'mitems' is here to transform the immutable object 'reminder' to mutable 
    echo $getTime()
    for reminder in g_reminders.mitems:
      let current_status = compareTime(timeInfoToTime(reminder.date))
      if current_status != reminder.status:
        reminder.status = current_status
      if reminder.alert and (current_status == ReminderStatus.Done or current_status == ReminderStatus.Soon):
        displayNotification(reminder)
      echo $reminder

    sleep(60000)
    

