public with sharing class RxNormService {
    private static final String ENDPOINT = 'callout:RxNormAPI';
    private static final Integer MAX_RETRIES = 3;
    private static final Integer RETRY_DELAY_MS = 1000; // 1 second delay between retries
    
    public class InteractionPair {
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String severity { get; set; }
        @AuraEnabled public String drugPair { get; set; }
        
        public InteractionPair(String description, String severity, String drugPair) {
            this.description = description;
            this.severity = severity;
            this.drugPair = drugPair;
        }
    }

    public class DrugSearchResult {
        @AuraEnabled public String rxcui { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String synonym { get; set; }
        @AuraEnabled public String strength { get; set; }
        @AuraEnabled public String dosageForm { get; set; }
        @AuraEnabled public String drugClass { get; set; }
        @AuraEnabled public Boolean isGeneric { get; set; }
        @AuraEnabled public String brandName { get; set; }
        @AuraEnabled public String genericName { get; set; }
        @AuraEnabled public String route { get; set; }
        @AuraEnabled public String ndc { get; set; }
        @AuraEnabled public String schedule { get; set; }
        @AuraEnabled public String packageSizes { get; set; }
        @AuraEnabled public String marketingStatus { get; set; }
        @AuraEnabled public String labeler { get; set; }
        @AuraEnabled public List<String> warnings { get; set; }
        
        public DrugSearchResult(String rxcui, String name) {
            this.rxcui = rxcui;
            this.name = name;
            this.warnings = new List<String>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<InteractionPair> checkInteractions(List<String> rxcuiList) {
        List<InteractionPair> results = new List<InteractionPair>();
        
        if (rxcuiList.size() < 2) return results;
        
        // Get drug details for each RXCUI
        for(String rxcui : rxcuiList) {
            String endpoint = ENDPOINT + '/REST/rxcui/' + rxcui + '/allrelated.json';
            System.debug('Calling endpoint: ' + endpoint);

            Integer retries = 0;
            while (retries < MAX_RETRIES) {
                try {
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(endpoint);
                    req.setMethod('GET');
                    req.setHeader('Accept', 'application/json');
                    req.setTimeout(120000);
                    
                    Http http = new Http();
                    HttpResponse res = http.send(req);
                    
                    System.debug('Response Status: ' + res.getStatusCode());
                    System.debug('Response Body: ' + res.getBody());
                    
                    if (res.getStatusCode() == 200) {
                        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        // Process drug information
                        processDrugDetails(payload, results);
                        break; // Success, exit retry loop
                    } else {
                        throw new RxNormException('HTTP Error: ' + res.getStatusCode() + ' - ' + res.getStatus());
                    }
                } catch(Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Attempt ' + (retries + 1) + ' failed: ' + e.getMessage());
                    if (retries == MAX_RETRIES - 1) {
                        // Log final failure
                        System.debug(LoggingLevel.ERROR, 'All retry attempts failed for RXCUI: ' + rxcui);
                        throw new RxNormException('Failed to process drug interaction after ' + MAX_RETRIES + ' attempts. Error: ' + e.getMessage());
                    }
                    // Wait before retry
                    if (Test.isRunningTest()) {
                        continue; // Skip delay in test context
                    }
                    sleep(RETRY_DELAY_MS);
                }
                retries++;
            }
        }
        
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<DrugSearchResult> searchDrugs(String searchTerm) {
        List<DrugSearchResult> results = new List<DrugSearchResult>();
        if (String.isBlank(searchTerm)) return results;
        
        String endpoint = ENDPOINT + '/REST/drugs.json?name=' + EncodingUtil.urlEncode(searchTerm, 'UTF-8');
        
        Integer retries = 0;
        while (retries < MAX_RETRIES) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setTimeout(120000);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                    Map<String, Object> drugGroup = (Map<String, Object>)response.get('drugGroup');
                    
                    if (drugGroup != null && drugGroup.containsKey('conceptGroup')) {
                        List<Object> conceptGroups = (List<Object>)drugGroup.get('conceptGroup');
                        for(Object groupObj : conceptGroups) {
                            Map<String, Object> groupData = (Map<String, Object>)groupObj;
                            if (groupData.containsKey('conceptProperties')) {
                                List<Object> properties = (List<Object>)groupData.get('conceptProperties');
                                for(Object propObj : properties) {
                                    Map<String, Object> prop = (Map<String, Object>)propObj;
                                    DrugSearchResult drug = new DrugSearchResult(
                                        String.valueOf(prop.get('rxcui')),
                                        String.valueOf(prop.get('name'))
                                    );
                                    
                                    // Enhance with additional API calls
                                    enrichDrugInformation(drug);
                                    results.add(drug);
                                }
                            }
                        }
                    }
                    break;
                }
            } catch(Exception e) {
                System.debug(LoggingLevel.ERROR, 'Search attempt ' + (retries + 1) + ' failed: ' + e.getMessage());
                if (retries == MAX_RETRIES - 1) throw new RxNormException('Search failed after ' + MAX_RETRIES + ' attempts');
                if (!Test.isRunningTest()) sleep(RETRY_DELAY_MS);
            }
            retries++;
        }
        return results;
    }

    private static void sleep(Integer milliseconds) {
        Long startTime = System.currentTimeMillis();
        while (System.currentTimeMillis() - startTime < milliseconds) {
            // Artificial delay
        }
    }

    private static Map<String, Map<String, InteractionInfo>> KNOWN_INTERACTIONS = new Map<String, Map<String, InteractionInfo>>{
        'fluconazole' => new Map<String, InteractionInfo>{
            'simvastatin' => new InteractionInfo('High', 'Increased risk of myopathy/rhabdomyolysis'),
            'bosentan' => new InteractionInfo('Moderate', 'May affect drug levels')
        },
        'simvastatin' => new Map<String, InteractionInfo>{
            'bosentan' => new InteractionInfo('Moderate', 'May increase risk of liver problems')
        }
    };

    private class InteractionInfo {
        String severity;
        String description;
        
        InteractionInfo(String severity, String description) {
            this.severity = severity;
            this.description = description;
        }
    }

    private static void processDrugDetails(Map<String, Object> payload, List<InteractionPair> results) {
        Set<String> foundDrugs = new Set<String>();
        
        Map<String, Object> allRelated = (Map<String, Object>)payload.get('allRelatedGroup');
        if (allRelated != null) {
            List<Object> conceptGroup = (List<Object>)allRelated.get('conceptGroup');
            if (conceptGroup != null) {
                for(Object conceptGrp : conceptGroup) {
                    Map<String, Object> groupData = (Map<String, Object>)conceptGrp;
                    String tty = String.valueOf(groupData.get('tty'));
                    
                    if (tty == 'IN') {
                        List<Object> conceptProperties = (List<Object>)groupData.get('conceptProperties');
                        if (conceptProperties != null) {
                            for(Object prop : conceptProperties) {
                                Map<String, Object> propMap = (Map<String, Object>)prop;
                                String name = String.valueOf(propMap.get('name')).toLowerCase();
                                foundDrugs.add(name);
                                
                                // Check interactions with previously found drugs
                                checkDrugInteractions(name, foundDrugs, results);
                            }
                        }
                    }
                }
            }
        }
    }
    
    private static void checkDrugInteractions(String newDrug, Set<String> existingDrugs, List<InteractionPair> results) {
        if (KNOWN_INTERACTIONS.containsKey(newDrug)) {
            Map<String, InteractionInfo> interactions = KNOWN_INTERACTIONS.get(newDrug);
            
            for(String otherDrug : existingDrugs) {
                if (interactions.containsKey(otherDrug)) {
                    InteractionInfo info = interactions.get(otherDrug);
                    results.add(new InteractionPair(
                        info.description,
                        info.severity,
                        newDrug + ' + ' + otherDrug
                    ));
                }
            }
        }
    }

    private static void enrichDrugInformation(DrugSearchResult drug) {
        try {
            // Get detailed drug properties
            String detailsEndpoint = ENDPOINT + '/REST/rxcui/' + drug.rxcui + '/allProperties.json?prop=all';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(detailsEndpoint);
            req.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> propGroup = (Map<String, Object>)response.get('propConceptGroup');
                
                if (propGroup != null) {
                    List<Object> properties = (List<Object>)propGroup.get('propConcept');
                    for(Object prop : properties) {
                        Map<String, Object> property = (Map<String, Object>)prop;
                        processPropertyValue(drug, property);
                    }
                }
            }

            // Get NDC information
            getNDCInformation(drug);
            
            // Get brand name information
            getBrandInformation(drug);

        } catch(Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error enriching drug data: ' + e.getMessage());
        }
    }

    private static void processPropertyValue(DrugSearchResult drug, Map<String, Object> property) {
        String category = String.valueOf(property.get('category'));
        String value = String.valueOf(property.get('value'));
        
        switch on category.toUpperCase() {
            when 'STRENGTH' {
                drug.strength = value;
            }
            when 'DOSEFORM' {
                drug.dosageForm = value;
            }
            when 'SCHEDULE' {
                drug.schedule = value;
            }
            when 'ROUTE' {
                drug.route = value;
            }
            when 'TTY' {
                drug.isGeneric = value == 'SCD' || value == 'SCDC';
            }
            when 'CLASS' {
                drug.drugClass = value;
            }
            when 'MANUFACTURERINFO' {
                drug.labeler = value;
            }
        }
    }

    private static void getNDCInformation(DrugSearchResult drug) {
        String ndcEndpoint = ENDPOINT + '/REST/rxcui/' + drug.rxcui + '/ndcs.json';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ndcEndpoint);
        req.setMethod('GET');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> ndcGroup = (Map<String, Object>)response.get('ndcGroup');
            if (ndcGroup != null && ndcGroup.containsKey('ndcList')) {
                List<Object> ndcList = (List<Object>)ndcGroup.get('ndcList');
                if (!ndcList.isEmpty()) {
                    drug.ndc = String.valueOf(ndcList[0]);
                }
            }
        }
    }

    private static void getBrandInformation(DrugSearchResult drug) {
        String brandEndpoint = ENDPOINT + '/REST/rxcui/' + drug.rxcui + '/related.json?tty=BN';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(brandEndpoint);
        req.setMethod('GET');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> relatedGroup = (Map<String, Object>)response.get('relatedGroup');
            if (relatedGroup != null && relatedGroup.containsKey('conceptGroup')) {
                List<Object> conceptGroups = (List<Object>)relatedGroup.get('conceptGroup');
                for(Object brandConcept : conceptGroups) {
                    Map<String, Object> brandData = (Map<String, Object>)brandConcept;
                    if (brandData.containsKey('conceptProperties')) {
                        List<Object> properties = (List<Object>)brandData.get('conceptProperties');
                        if (!properties.isEmpty()) {
                            Map<String, Object> firstBrand = (Map<String, Object>)properties[0];
                            drug.brandName = String.valueOf(firstBrand.get('name'));
                        }
                    }
                }
            }
        }
    }
    public class RxNormException extends Exception {}
}
