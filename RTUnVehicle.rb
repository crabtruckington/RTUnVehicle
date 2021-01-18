begin
    require 'json'
    require 'fileutils'
    require 'date'
    require_relative 'DefaultMechs'

    #Setting up initial variables
    begin
        lanceFiles = Dir.glob("./Lances/*/*.json")
    rescue => exception
        #if the user forgot to copy the Lances file, or if we cant read it for some reason
        #tell them, and then exit the script since nothing will work properly
        puts exception.to_s
        puts "RogueTech Lances folder cannot be found! Did you remember to copy it first?"
        puts "Please go to your Battletech installation directory and copy the"
        puts "\\Mods\\RogueTech Core\\Lances\\"
        puts "folder into the same directory as this script."
        puts "Otherwise, most likely you are running this script from a directory"
        puts "that you do not have access to, such as the Program Files or User directories"
        puts "Please copy the script and Lances folder to a directory such as C:\\RTUnVehicle\\ and try again"
        exit 0
    end

    oldLanceFolder = "./Lances/"
    newLanceFolder = "./NewLances/"
    @logFile = "./unVehicle" + Time.new.strftime("%Y%m%d%H%M%S") + ".log"
    removeVTOLs = false
    userWantsToRemoveVTOLs = ""
    
    #Message logging method
    def log (logMessage)
        begin
            time = Time.new
            logString = "[" + time.strftime("%H:%M:%S %d-%m-%Y") + "] " + logMessage

            File.open(@logFile, "a") do |f|
                f.puts logString.to_s        
            end
            puts logString
        rescue => exception
            puts exception.to_s
            puts "Cannot write log file!!"
            puts "Are you sure you have placed the script in a directory you have read/write access to?"
            exit 0
        end
    end

    #print info and ask for user input
    log("Thank you for using the RTUnVehicle script!")
    log("This script will remove the majority of vehicles from the spawn pool")
    log("Some vehicles will still remain, specifically vehicles spawned during")
    log("missions that require vehicles, like Convoys, or missions that")
    log("tell you your opponents will be a vehicle-based unit")
    log(" ")
    log("Optionally, you can completely remove VTOLs from the spawn pool")
    log("This will likely increase difficulty!")
    log("Also, some special VTOLs will likely remain (Legendary VTOLs or Named VTOLs)")
    log("Do you want to remove VTOLs from the spawn pool? (Optional, default no) (y/n):")
    userWantsToRemoveVTOLs = gets    
    #sanitize and check user input, set vtol removal flag
    userWantsToRemoveVTOLs = userWantsToRemoveVTOLs.downcase.chomp

    log(userWantsToRemoveVTOLs.to_s)
    if (userWantsToRemoveVTOLs == "y" || userWantsToRemoveVTOLs == "ye" || userWantsToRemoveVTOLs == "yes")
        removeVTOLs = true
    else
        removeVTOLs = false
    end
    log(removeVTOLs.to_s)

    #main script
    begin
        #create NewLances folder if it doesnt exist yet
        Dir.mkdir(newLanceFolder) unless File.exists?(newLanceFolder)

        #for each Lance json from the RogueTech files, loop through looking for ones that arent entirely vehicle specific
        lanceFiles.each do |file|
            #if (file.downcase.include?("convoy") || file.downcase.include?("vehicle") || file.downcase.include?("vtol"))
            if (file.downcase.include?("convoy") || file.downcase.include?("vtol"))
                #if the user wants to remove VTOLs, we will do it here
                if (removeVTOLs)
                    currentFile = File.open(file)
                    jsonObject = JSON.load(currentFile)
                    currentFile.close

                    noVTOLLanceUnitArray = Array.new
                    vtolsFoundInUnitTagSet = false
                    mechFoundInLanceUnit = false
                    excludeVTOLTagFound = false
                    lanceDifficulty = jsonObject["Difficulty"]
                    log("lanceDifficulty = " + lanceDifficulty.to_s)

                    #for vtol removal, 
                    jsonObject["LanceUnits"].each do |unit|                            
                        noVTOLUnitTagSetArray = Array.new                       
                        
                        if (unit["unitType"] == "Vehicle")
                            unitTagSet = unit["unitTagSet"]
                            unitTagSet["items"].each do |tag|
                                if (tag == "unit_vtol")
                                    vtolsFoundInUnitTagSet = true
                                end
                            end
                        elsif (unit["unitType"] == "Mech")
                            mechFoundInLanceUnit = true
                        end

                        unit["excludedUnitTagSet"]["items"].each do |tag|
                            if (tag == "unit_vtol")
                                excludeVTOLTagFound = true;
                            end
                        end

                        if (vtolsFoundInUnitTagSet == false)
                            if (excludeVTOLTagFound == false)
                                log("Adding vehicle exclude tag")
                                unit["excludedUnitTagSet"]["items"].push("unit_vtol")
                            end
                            noVTOLLanceUnitArray.push(unit)
                        else
                            log("Found a VTOL! Replacing with a default mech")
                            noVTOLLanceUnitArray.push(JSON.parse(DefaultMechs.getDefaultMech(lanceDifficulty)))
                            mechFoundInLanceUnit = true
                        end
                        excludeVTOLTagFound = false
                    end

                    jsonObject["LanceUnits"] = noVTOLLanceUnitArray
                    if (mechFoundInLanceUnit == false && file.downcase.include?("convoy") == false && file.downcase.include?("vehicle") == false)
                        log("No mechs found in lance file " + file.to_s + ", adding a default mech")
                        jsonObject["LanceUnits"].push(JSON.parse(DefaultMechs.getDefaultMech(lanceDifficulty)))
                    end

                    #write the new file with our changes
                    newFileName = file.sub(oldLanceFolder, newLanceFolder)
                    newPath = File.dirname(newFileName)
                    log("Copying Updated Lance File To: " + newFileName)
                    Dir.mkdir(newPath) unless File.exists?(newPath)
                    File.write(newFileName, JSON.pretty_generate(jsonObject))
                else                
                    #if the lance only includes vehicles and the user doesnt want to remove all VTOLs, we copy it as is
                    newFileName = file.sub(oldLanceFolder, newLanceFolder)
                    newPath = File.dirname(newFileName)
                    log("Copying New Lance File Untouched... " + newFileName)
                    Dir.mkdir(newPath) unless File.exists?(newPath)
                    File.write(newFileName, File.read(file))
                end
            else 
                #if the lance contains combined arms, we will work on it
                currentFile = File.open(file)
                jsonObject = JSON.load(currentFile)
                currentFile.close

                #this Array holds our new Mech-Only Lance
                noVehicleLanceUnitArray = Array.new
                lanceDifficulty = jsonObject["Difficulty"]
                log("lanceDifficulty = " + lanceDifficulty.to_s)

                #This section loops over the possible unit spawns and ignores Vehicle options, putting
                #the Mech choices into a new list
                jsonObject["LanceUnits"].each do |unit|
                    if (unit["unitType"] == "Vehicle")
                        #replace with a default mech
                        log("Replacing a vehicle!")
                        noVehicleLanceUnitArray.push(JSON.parse(DefaultMechs.getDefaultMech(lanceDifficulty)))
                    else
                        #add non-vehicle definitions to our new Lance definition
                        noVehicleLanceUnitArray.push(unit)
                    end
                end
                #here we overwrite the existing combined arms Lance with our new Mech-Only lance we built above
                jsonObject["LanceUnits"] = noVehicleLanceUnitArray

                #finally, we copy the new Lance json file to the NewLances folder in the proper directory
                newFileName = file.sub(oldLanceFolder, newLanceFolder)
                newPath = File.dirname(newFileName)
                log("Copying Updated Lance File To: " + newFileName)
                Dir.mkdir(newPath) unless File.exists?(newPath)
                File.write(newFileName, JSON.pretty_generate(jsonObject))
            end
        end

        #this section simply provides details for the user afterwards so they can utilize the generated files
        log(" ")
        log("UnVehicle process complete!")
        log("To install these new files, Please delete the Directories in")
        log("\[BATTLETECH INSTALL FOLDER\]\\Mods\\RogueTech Core\\Lances\]") 
        log("and replace them with the directories in \"NewLances\"")
        log("Make sure to take a backup of the original Lances folder in case something has gone wrong!")
        log("In the worst case scenario, run the RogueTech launcher repair option.")
    rescue => exception
        #catch any problems encountered above and print the error message to the logs
        log(exception.to_s)
        log("Something has gone wrong!")
        log("Please report this issue, including this error message as")
        log("well as the generated log file for troubleshooting")
        exit 0
    end
rescue => exception
    #general catch all, in case something has gone wrong that we didnt consider
    puts exception.to_s
    puts "Something has gone wrong!"
    puts "Please report this issue, including this error message as"
    puts "well as the generated log file for troubleshooting"
    exit 0
end
