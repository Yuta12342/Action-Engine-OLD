
/**
 * A Work in Progress object for making a new Script Language for FNF, to make things simpler.
 */
class FunSkriptInterpreter {
    public function new() {
        // Constructor code here
    }

    public function interpretFile(filePath:String):Void {
        // Read the file contents
        var fileContents:String = Sys.io().readFile(filePath);

        // Tokenize the file contents
        var tokens:Array<String> = tokenize(fileContents);

        // Parse and execute the tokens
        parseAndExecute(tokens);
    }

    private function tokenize(fileContents:String):Array<String> {
        // Split the file contents into lines
        var lines:Array<String> = fileContents.split("\n");

        // Split each line into words
        var tokens:Array<String> = [];
        for (line in lines) {
            var words:Array<String> = line.split(" ");
            tokens = tokens.concat(words);
        }

        return tokens;
    }

    private function parseAndExecute(tokens:Array<String>):Void {
        // For each token, execute the corresponding command
        for (token in tokens) {
            executeCommand(token);
        }
    }

    private function executeCommand(command:String):Void {
        // Split the command into words
        var words:Array<String> = command.split(" ");

        // Execute the command
        switch (words[0]) {
            case "sprite":
                // Check if the command has the correct number of arguments
                if (words.length != 4 || words[1] != "=" || words[3] != "()") {
                    throw 'Invalid syntax for sprite command: $command';
                }

                // Create a sprite in PlayState
                var name:String = words[2];
                var filePath:String = words[3].substr(1, words[3].length - 2); // Remove the parentheses
                PlayState.createSprite(name, filePath);
            default:
                throw 'Unknown command: $command';
        }
    }
}