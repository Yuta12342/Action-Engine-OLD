class FunctionContainer
{
	private var functions:Array<Dynamic>;

	public function new()
	{
		functions = [];
	}

	public function addFunction(func:Dynamic):Void
	{
		functions.push(func);
	}

	public function callFunctions():Void
	{
		for (func in functions)
		{
			func();
		}
	}
}
