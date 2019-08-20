# Update ClickOnce

This extension gives you the ability to modify an existing ClickOnce package.
Specify your ClickOnce application and you can modify any of these properties:
  - Application Name
  - Publisher
  - Certificate file
  - Provider Url
  - Version number
  - Minimum version
  - Advanced configuration using JSON

# How to
Set up your normal build process, then in your release task use this extension to modify the needed properties.  
Version and minimum version must be a string containing the version in the format "N.N.N.N", where "N" is an unsigned 32-bit integer.  
In minimum version you can use "%version%", this will be replaced with "Version number" if provided else the current assembly version will be used.  

Since Mage is used to modify the ClickOnce package more valuable information can be found here: [Mage.exe ref](https://docs.microsoft.com/en-us/dotnet/framework/tools/mage-exe-manifest-generation-and-editing-tool#syntax) 
  
Then use normal DevOps task Copy Files to deploy your ClickOnce files

# Advanced modification
The advanced feature gives you the ability to modify any part of the .application file using a JSON string specifying witch existing node and property to update.  
>Be aware that some changes might break the functionality if used wrongly

This is an example of the required JSON structure:  
```json
{  
"advanced": [  
      {  
        "ElementPath": "assembly.assemblyIdentity",  
        "AttributeName": "name",  
        "AttributeValue": "MyNew.Net.application"  
      },  
      {  
        "ElementPath": "assembly.description",  
        "AttributeName": "publisher",  
        "AttributeValue": "Your name"  
      }  
	]  
}  
```
