/**
 * @description       : 
 * @author            : James Loghry (Demand Chain)
 * @group             : 
 * @last modified on  : 05-12-2021
 * @last modified by  : James Loghry (Demand Chain)
 * Modifications Log
 * Ver   Date         Author                        Modification
 * 1.0   05-06-2021   James Loghry (Demand Chain)   Initial Version
**/
public with sharing class BitbucketCallout extends CalloutUtil{
    private Map<String,String> headers {get; set;}

    public BitbucketCallout() {
        super('Bitbucket');
        this.headers = new Map<String,String>{
            'Content-Type' => 'application/json',
            'User-Agent' => 'demand-chain'
        };
    }

    //public override String get(String api) {
    //    return super.get(api, this.headers);
    //}

    public override String post(String api, String body) {
        return super.post(api, body, this.headers);
    }

    public override String put(String api, String body) {
        return super.put(api, body, this.headers);
    }

    /*public void createRepository(String repositoryName){
        Repository r = new Repository();
        r.name = repositoryName;
        //r.slug = 'https://bitbucket.org/demandchain/' + repositoryName + '.git';
        r.project = new Project();
        r.project.key = 'HM';
        r.is_private = true;
        post('/repositories/demandchain/' + repositoryName, JSON.serialize(r,true));
    }*/

    public void createSchedule(String repositoryName, String cron){
        Schedule s = new Schedule();
        s.enabled = true;
        s.cron_pattern = cron;
        s.type_x = 'pipeline_schedule';
        s.target = new Target();
        s.target.type_x = 'pipeline_ref_target';
        s.target.ref_type = 'branch';
        s.target.ref_name = 'master';
        s.target.selector = new Selector();
        s.target.selector.type_x = 'custom';
        s.target.selector.pattern = 'default';
        String request = JSON.serialize(s,true).replace('type_x','type');
        post('/repositories/demandchain/' + repositoryName + '/pipelines_config/schedules/', request);
    }

    public void createFork(String repositoryName){
        Fork fork = new Fork();
        fork.name = repositoryName;
        fork.workspace = new Workspace();
        fork.workspace.slug = 'demandchain';
        fork.project = new Project();
        fork.project.key = 'HM';
        fork.is_private = true;
        post('/repositories/demandchain/sfdx-template/forks', JSON.serialize(fork,true));
    }

    public void createPipelineVariable(String repositoryName, String variable, String value){
        PipelineVariable pv = new PipelineVariable();
        pv.key = variable;
        pv.value = value;
        pv.secured = true;
        post('/repositories/demandchain/' + repositoryName + '/pipelines_config/variables/', JSON.serialize(pv,true));
    }

    public void enablePipeline(String repositoryName, boolean enabled){
        EnablePipeline ep = new EnablePipeline();
        ep.enabled = enabled;
        put('/repositories/demandchain/' + repositoryName + '/pipelines_config', JSON.serialize(ep,true));
    }

    public void createBranch(String repositoryName, String branchName){
        Branch b = new Branch();
        b.name = branchName;
        b.target = new BranchTarget();
        b.target.hash = 'master';
        post('/repositories/demandchain/' + repositoryName + '/refs/branches', JSON.serialize(b,true));
    }

    /*public class Repository{
        public Project project {get; set;}
        public String name {get; set;}
        public String slug {get; set;}
        public boolean is_private {get; set;}
    }*/

    public class Project{
        public String key {get; set;}
    }

    public class Fork{
        public String name {get; set;}
        public Workspace workspace {get; set;}
        public Project project {get; set;}
        public boolean is_private {get; set;}
    }

    public class Workspace{
        public String slug {get; set;}
    }

    public class Schedule{
        public String type_x {get; set;}
        public boolean enabled {get; set;}
        public Target target {get; set;}
        public String cron_pattern {get; set;}
    }

    public class Target{
        public String type_x {get; set;}
        public String ref_type {get; set;}
        public String ref_name {get; set;}
        public Selector selector {get; set;}
    }

    public class Selector{
        public String type_x {get; set;}
        public String pattern {get; set;}
    }

    public class Branch{
        public String name {get; set;}
        public BranchTarget target {get; set;}
    }

    public class BranchTarget{
        public String hash {get; set;}
    }

    public class PipelineVariable{
        public String key {get; set;}
        public String value {get; set;}
        public boolean secured {get; set;}
    }

    public class EnablePipeline{
        public boolean enabled {get; set;}
    }
}