class Filer
  
  # Set the snapshot schedule for a volume
  # == Parameters
  #  volume -- volume name [required]
  #  weeks  -- number of weekly snapshots to keep
  #  days   -- number of daily snapshots to keep
  #  hours  -- number of hourly snapshots to keep
  #  which  -- Comma-separated list of the hours at which the hourly snapshots are created [optional]
  def snap_sched(volume, weeks = 8, days = 10, hours = 24, which_hours = nil)
    output = @filer.invoke("snapshot-set-schedule","volume",volume,
                           "weeks", weeks, "days", days, "hours", hours, "which-hours", which_hours)
    if (output.results_status() == "failed")
      raise "Error setting #{output.results_errno} #{output.results_reason()}\n"
    end
  end
  
end