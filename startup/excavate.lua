local status = settings.get("excavation.in_progress")
if status == nil then
    status = false
    settings.set("excavation.in_progress", status)
    settings.save()
end

if status then
    print("Excavation already in progress")
    shell.run("/programs/excavate", "proceed")
end