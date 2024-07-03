class MoldQ {
    #TODO Make certain things as mandatory
    [string]$Type
    [string]$Key
    [string]$Caption
    [string]$Message
    [string]$Prompt
    [string]$Default
    [hashtable]$Choice
    [string]$Answer

    MoldQ ([hashtable]$obj) {
        $this.Caption = $obj.Caption
        $this.Key = $obj.Key
        $this.Message = $obj.Message
        $this.Prompt = $obj.Prompt
        $this.Default = $obj.Default
        $this.Type = $obj.Type
        $this.Choice = $obj.Choice
    }
}
