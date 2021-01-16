require 'json'
require 'fileutils'
require 'date'

lanceFiles = Dir.glob("./Lances/*/*.json")
oldLanceFolder = "./Lances/"
newLanceFolder = "./NewLances/"
@logFile = "./unVehicle" + Time.new.strftime("%Y%m%d%H%M%S") + ".log"
#newJsonArray = Array.new


def log (logMessage)
    time = Time.new
    logString = "[" + time.strftime("%H:%M:%S %d-%m-%Y") + "] " + logMessage
    
    File.open(@logFile, "a") do |f|
        f.puts logString.to_s        
    end
    puts logString    
end

begin
    Dir.mkdir(newLanceFolder) unless File.exists?(newLanceFolder)

    lanceFiles.each do |file|
        if (file.downcase.include?("convoy") || file.downcase.include?("vehicle") || file.downcase.include?("vtol"))
            #puts "Writing File As Is... " + file
            newFileName = file.sub(oldLanceFolder, newLanceFolder)
            newPath = File.dirname(newFileName)
            log("Copying New Lance File Untouched... " + newFileName)
            Dir.mkdir(newPath) unless File.exists?(newPath)
            File.write(newFileName, File.read(file))
        else 
            currentFile = File.open(file)
            jsonObject = JSON.load(currentFile)
            currentFile.close

            noVehicleLanceUnitArray = Array.new

            jsonObject["LanceUnits"].each do |unit|
                if (unit["unitType"] == "Vehicle")
                    #jsonObject.tap { |thisUnit| thisUnit.delete(unit) }
                else
                    noVehicleLanceUnitArray.push(unit)
                end
            end
            jsonObject["LanceUnits"] = noVehicleLanceUnitArray
            # noVehicleLanceUnitArray.push(jsonObject)

            newFileName = file.sub(oldLanceFolder, newLanceFolder)
            newPath = File.dirname(newFileName)
            log("Copying Updated Lance File To: " + newFileName)
            Dir.mkdir(newPath) unless File.exists?(newPath)
            File.write(newFileName, JSON.pretty_generate(jsonObject))
        end
    end

    log("")
    log("UnVehicle process complete!")
    log("To install these new files, Please delete the Directories in")
    log("\[BATTLETECH INSTALL FOLDER\]\\Mods\\RogueTech Core\\Lances\]") 
    log("and replace them with the directories in \"NewLances\"")
    log("Make sure to take a backup of the original Lances folder in case something has gone wrong!")
    log("In the worst case scenario, run the RogueTech launcher repair option.")
rescue => exception
    log(exception)
end
# File.open("./testLanceJson.json", "w+") do |f|
#     f.puts(JSON.pretty_generate(newJsonArray))
# end

