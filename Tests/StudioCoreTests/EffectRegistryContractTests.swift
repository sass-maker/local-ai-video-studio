import Foundation
import Testing

@testable import StudioCore

// The registry is the closed schema the validator enforces and the planner is
// constrained to. These tests assert the registry is internally consistent, so a
// default that no longer satisfies its own rule fails here rather than surfacing
// as a rejected graph at render time.

private let registry = EffectRegistry.standard

@Test func standardRegistryDefinesEveryEffectTypeExactlyOnce() {
  let types = registry.allDefinitions.map(\.type)

  #expect(types.count == EffectType.allCases.count)
  #expect(Set(types) == Set(EffectType.allCases))
}

@Test func everyDeclaredParameterDefaultSatisfiesItsOwnRule() {
  for definition in registry.allDefinitions {
    for descriptor in definition.parameters {
      #expect(
        descriptor.rule.contains(descriptor.defaultValue),
        "\(definition.type.rawValue).\(descriptor.kind.rawValue) default is outside its rule")
    }
  }
}

@Test func declaredParametersMatchTheNumericDefaultParameters() {
  for definition in registry.allDefinitions {
    let declared = Dictionary(
      uniqueKeysWithValues: definition.parameters.map { ($0.kind, $0.defaultValue) })
    let defaults = definition.defaultParameters

    #expect(defaults.strength == declared[.strength])
    #expect(defaults.intensity == declared[.intensity])
    #expect(defaults.rate == declared[.rate])
    #expect(defaults.duration == declared[.duration])
  }
}

@Test func textParameterDefaultsAreThemselvesValidOptions() {
  for definition in registry.allDefinitions {
    for descriptor in definition.textParameters where !descriptor.options.isEmpty {
      #expect(
        descriptor.options.contains(descriptor.defaultValue),
        "\(definition.type.rawValue).\(descriptor.kind.rawValue) default is not an option")
    }
  }
}

@Test func defaultParametersCarryEveryDeclaredTextDefault() throws {
  for definition in registry.allDefinitions {
    let defaults = definition.defaultParameters
    let byKind = Dictionary(
      uniqueKeysWithValues: definition.textParameters.map { ($0.kind, $0.defaultValue) })

    #expect(defaults.target == byKind[.target])
    #expect(defaults.preset == byKind[.preset])
    #expect(defaults.text == byKind[.text])
  }

  // The four effects that carry text-shaped parameters at all.
  #expect(try #require(registry[.cropAutoSubject]).defaultParameters.target == "primary_person")
  #expect(try #require(registry[.captionDynamic]).defaultParameters.preset == "bold")
  #expect(try #require(registry[.titleCard]).defaultParameters.text == "Title")
  #expect(try #require(registry[.backgroundReplace]).defaultParameters.preset == "soft_gradient")
  #expect(try #require(registry[.speed]).defaultParameters.target == nil)
}

@Test func onlyStyleEffectsAreApproximationsAndFallbacksCarryAReason() {
  for definition in registry.allDefinitions {
    if definition.readiness == .fallback {
      #expect(definition.fallbackReason != nil)
    } else {
      #expect(definition.fallbackReason == nil)
      #expect(definition.isApproximation == (definition.readiness == .approximation))
    }
  }
}

@Test func parameterRuleRejectsValuesOutsideItsBounds() {
  let rule = ParameterRule(0.25, 4)

  #expect(rule.contains(0.25))
  #expect(rule.contains(4))
  #expect(rule.contains(1))
  #expect(!rule.contains(0.24))
  #expect(!rule.contains(4.01))
}
