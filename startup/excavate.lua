local status = settings.get("excavation.in_progress")
if status == nil then
    settings.set("excavation.in_progress", false)
    settings.save()
    status = false
end

if status then
    print("Excavation already in progress")
    shell.run("/programs/excavate", "proceed")
end