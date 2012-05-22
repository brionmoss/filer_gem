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
      raise "Error #{output.results_errno} setting snap sched on #{volume}: #{output.results_reason()}\n"
    end
  end
  
  # List the snapshots on a volume
  # == Parameters
  # volume name
  # == Returns
  # Hash { snapname => {'time' => Time, busy => (true/false), 'dependency' => "things" }, }
  # Note that the name will be a string, the time will be a ruby Time object, and busy will be boolean
  #  Dependency will show what (if anything) depends on this snapshot -- will be a comma-separated list
  #  that could include "snapmirror", "snapvault","dump", "vclone", "luns", "snaplock"
  def snap_list(volume)
    snapshots = {}
    output = @filer.invoke("snapshot-list-info","volume",volume,"terse","true")
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} listing snapshots on #{volume}: #{output.results_reason()}\n"
    end
    output.child_get("snapshots").children_get.each do |snap| 
      snapshots[snap.child_get_string("name")] = {
        'time' => Time.at(snap.child_get_string("access-time").to_i),
        'busy' => (snap.child_get_string("busy") == "true"),
        'dependency' => snap.child_get_string("dependency")
      }
    end
    snapshots
  end
  
  # Delete a snapshot
  # == Parameters
  # Volume name, snapshot name
  def snap_delete(volume,snapshot)
    output = @filer.invoke("snapshot-delete","volume",volume,"snapshot",snapshot)
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} deleting snapshot #{snapshot} on #{volume}: #{output.results_reason()}\n"
    end
  end
  
  # Create a snapshot
  # == Parameters
  # Volume name, snapshot name
  def snap_delete(volume,snapshot)
    output = @filer.invoke("snapshot-create","volume",volume,"snapshot",snapshot)
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} creating snapshot #{snapshot} on #{volume}: #{output.results_reason()}\n"
    end
  end
end