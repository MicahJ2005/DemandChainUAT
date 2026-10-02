trigger GPTPromptProcessorTrigger on Account (before insert) {
    for (Account a : Trigger.New) {
        System.debug('hello');
    }
}